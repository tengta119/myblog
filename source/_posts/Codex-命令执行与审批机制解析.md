---
title: Codex 命令执行与审批机制解析
tags:
  - AI
  - Codex
  - 沙箱
categories:
  - AI
type: story
date: 2026-09-06 15:00:03
cover: https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/codex-%E5%91%BD%E4%BB%A4%E6%89%A7%E8%A1%8C%E4%B8%8E%E5%AE%A1%E6%89%B9%E6%9C%BA%E5%88%B6%E6%BA%90%E7%A0%81%E8%A7%A3%E6%9E%90-01.png
render:
  diagrams: mermaid

---

>  **execpolicy 规则 → 危险命令启发式 → 审批策略 → 沙箱 → 权限升级重试** 的完整过程。

Codex 执行命令时，由以下几个层面共同决定：

1. **execpolicy 显式规则**（`allow` / `prompt` / `forbidden`）
2. **内置 fallback**——未命中任何显式规则时，由 core 依据危险命令检查、审批策略与沙箱状态给出的默认判断
3. **AskForApproval**——决定当前环境是否允许向用户发起审批
4. **沙箱**——即使命令获准执行，也限制它实际能读、写、连接的资源
5. **审批缓存、权限升级与失败重试**——一次执行可能经历"沙箱内尝试 → 被拒 → 请求更高权限 → 重试"

整体决策链路如下：

![](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/codex-%E5%91%BD%E4%BB%A4%E6%89%A7%E8%A1%8C%E4%B8%8E%E5%AE%A1%E6%89%B9%E6%9C%BA%E5%88%B6%E6%BA%90%E7%A0%81%E8%A7%A3%E6%9E%90-01.png)

---

## 决策三种状态与显式规则

**三种决策的定义与语义。** `Decision` 定义在 `execpolicy/src/decision.rs:8`，只有三种取值：

```rust
#[derive(Clone, Copy, Debug, Eq, PartialEq, Ord, PartialOrd, Serialize, Deserialize)]
pub enum Decision {
    /// Command may run without further approval.
    Allow,
    /// Request explicit user approval; rejected outright when running with `approval_policy="never"`.
    Prompt,
    /// Command is blocked without further consideration.
    Forbidden,
}
```

- **`Allow`**：命令在策略层面允许执行，无需进一步审批；
- **`Prompt`**：命令需要显式用户审批；若运行在 `approval_policy="never"` 下会被直接拒绝（审批策略见第 6 章）；
- **`Forbidden`**：命令被策略封禁，不再考虑用户是否批准。

`Decision::parse`负责把 Starlark/配置里的字符串 `"allow"` / `"prompt"` / `"forbidden"` 解析为对应变体。

**合并规则：为什么"最严格者胜出"。** 关键在于 `Decision` 派生了 **`Ord` / `PartialOrd`**，变体的**声明顺序**即严重级别顺序：

```text
Allow < Prompt < Forbidden
```

而 `Evaluation::from_matches`（[`execpolicy/src/policy.rs:403`](codex-rs/execpolicy/src/policy.rs)）对所有匹配结果取 `max()`：

```rust
let decision = matched_rules.iter().map(RuleMatch::decision).max();
```

因此当一条命令同时命中多条规则时，合并规则是：

```text
Forbidden > Prompt > Allow
```

即：

```text
allow + prompt              → Prompt
prompt + forbidden          → Forbidden
allow + prompt + forbidden  → Forbidden
```

**所有匹配规则中最严格的决策胜出。**

**`prefix_rule`：token 前缀匹配而非字符串包含。** 规则在 policy 文件中用 Starlark 语法声明，例如：

```starlark
prefix_rule(
    pattern = ["cargo", "test"],
    decision = "allow",
)
```

`PrefixPattern::matches_prefix`（`execpolicy/src/rule.rs:46`）逐条检查：

1. 命令的 token 数 **不少于** 规则长度；
2. **第一个 token 与规则首 token 相等**（policy 内部以首 token 为 key 组织索引，见第 2 章）；
3. 后续 token 与规则逐一相等；
4. 规则匹配后，命令**仍可携带更多参数**——前缀匹配只要求"规则是命令的前缀"。

因此：

```text
cargo test          → 匹配
cargo test --release → 匹配
cargo build          → 不匹配
```

**token 备选与省略的 `decision`。** 规则中的某个位置可以是多选一：

```starlark
prefix_rule(
    pattern = ["git", ["status", "diff"]],
    decision = "allow",
)
```

`PatternToken::Single` / `PatternToken::Alts`（`rule.rs`）分别表示定值 token 与备选 token。上面的规则同时匹配 `git status` 和 `git diff`。

另外，`decision` 可以省略：`execpolicy/src/parser.rs:357`中默认取 `Allow`：

```rust
let decision = match decision {
    Some(raw) => Decision::parse(raw)?,
    None => Decision::Allow,
};
```

也就是说，`prefix_rule(pattern = ["ls"])` 等价于显式的 `allow`。

---

## 规则查找、聚合与 fallback

**三条查找路径。** 规则查找的核心入口是 `Policy::matches_for_command_with_options`，顺序是：

```text
1. 精确规则：以命令第一个 token 为 key 查表（match_exact_rules）
2. 命中为空时：host executable basename 规则（match_host_executable_rules）
3. 仍然为空时：调用 heuristics fallback（core 注入的默认判断）
```

对应代码骨架：

```rust
let matched_rules = self
    .match_exact_rules(cmd)
    .filter(|rules| !rules.is_empty())
    .or_else(|| {
        options
            .resolve_host_executables
            .then(|| self.match_host_executable_rules(cmd))
            .filter(|matched_rules| !matched_rules.is_empty())
    })
    .unwrap_or_default();

if matched_rules.is_empty()
    && let Some(heuristics_fallback) = heuristics_fallback
{
    vec![RuleMatch::HeuristicsRuleMatch { ... }]
} else {
    matched_rules
}
```

几点值得注意：

- **`match_exact_rules`**用 `cmd.first()` 作为 key 查 `rules_by_program`，所以同一首 token 下的所有前缀规则会一次取出；
- **host executable 匹配**只在启用了 `resolve_host_executables`（core 默认开启）时尝试，它会取命令的 basename（如 `/usr/bin/git` → `git`）去匹配规则，并且会额外与 `host_executables_by_name` 对照，确认该绝对路径确实是系统已知的可执行文件——因此 `/usr/bin/git status` 在无精确规则时可能回退命中 `git status` 的规则；
- **只要精确规则命中任意一条，就不会再走 host executable，更不会触发 fallback**

**多条规则与复合命令的聚合。**

```starlark
prefix_rule(pattern = ["git"], decision = "allow")
prefix_rule(pattern = ["git", "push"], decision = "prompt")
prefix_rule(pattern = ["git", "push", "--force"], decision = "forbidden")
```

执行 `git push --force origin main` 会同时命中三条规则，`from_matches` 取 `max()`，结果为 **`Forbidden`**。

复合命令则通过 `Policy::check_multiple_with_options`先把命令按 `IntoIterator` 逐段检查，收集**所有子命令段**的匹配结果，再统一交给 `Evaluation::from_matches` 合并：

```rust
let matched_rules: Vec<RuleMatch> = commands
    .into_iter()
    .flat_map(|command| {
        self.matches_for_command_with_options(command.as_ref(), Some(heuristics_fallback), options)
    })
    .collect();

Evaluation::from_matches(matched_rules)
```

例如一个复合命令同时包含：

```text
cd project   → Allow
cargo test   → Prompt
git status   → Allow
```

最终整个复合命令的决策是 **`Prompt`**；只要**任何一段**是 `Forbidden`，整体就是 `Forbidden`。

> 这些"命令段"由 core 侧的 `commands_for_exec_policy_for_platform`产出：优先尝试用 shell 解析器抽取 `sh -c` / `bash -lc` 中的字面量命令；在 Windows 上再尝试 PowerShell 命令解析；都失败则把整条命令作为单一段处理。

**为什么需要 fallback。**

```text
prefix_rule = 用户或配置声明的显式策略
fallback     = 没有显式策略时，系统内置的默认判断
```

`execpolicy` 包本身**不知道**什么是"危险命令"，也不知道当前审批策略是什么。它通过函数回调接收 fallback：

```rust
pub fn check_with_options<F>(
    &self,
    cmd: &[String],
    heuristics_fallback: &F,
    options: &MatchOptions,
) -> Evaluation
where
    F: Fn(&[String]) -> Decision,
```

回调只在**没有任何显式规则命中**时被调用，产出一条特殊记录：

```rust
RuleMatch::HeuristicsRuleMatch {
    command: cmd.to_vec(),
    decision: heuristics_fallback(cmd),
}
```

因此：

```text
命中 prefix_rule → 使用显式规则，不调用 fallback
未命中 prefix_rule → 调用 fallback
```

fallback 单独存在，是因为：

- 没有规则文件 / 规则没覆盖到时，仍需要默认的安全行为；
- 危险命令可能被 `sudo`、`env`、`trap` 甚至 shell 字符串包装，需要专门识别；
- fallback 的默认结果**依赖当前的审批策略与沙箱状态**，不是一个可以静态写死的规则；
- 把审批与沙箱的决策逻辑留在 core，`execpolicy` 包就不必反向依赖 core 的实现。

**两类匹配结果：显式规则与启发式。** `RuleMatch` 有两种变体：

```rust
RuleMatch::PrefixRuleMatch {
    matched_prefix: Vec<String>,   // 命中的前缀 token
    decision: Decision,
    resolved_program: Option<...>,
    justification: Option<String>, // 规则的补充说明，可透出到提示/拒绝文案
}
RuleMatch::HeuristicsRuleMatch {
    command: Vec<String>,
    decision: Decision,
}
```

core 借此区分两种审批来源："用户配置的规则审批" 与 "系统内置启发式审批"——例如第 6 章里把 `Yes, and don't ask again...` 持久化为新规则的逻辑（execpolicy amendment），只会针对可固化为规则的场景生成。

---

## 未匹配命令的默认裁决

**注入点与实现位置。** core 在构造 fallback 闭包：

```rust
let exec_policy_fallback = |cmd: &[String]| {
    render_decision_for_unmatched_command_for_platform(
        cmd,
        UnmatchedCommandContext {
            approval_policy,
            permission_profile: &permission_profile,
            windows_sandbox_level,
            sandbox_permissions,
            command_origin,
        },
        command_platform,
    )
};
```

真正实现是 `render_decision_for_unmatched_command_for_platform`。它先做危险命令检查，再结合审批策略、文件系统沙箱与权限请求得出结论。

**危险命令，或无沙箱保护 → 宁问不放。** 对应代码：

```rust
if dangerous_command_match.is_some()
    || windows_managed_fs_restrictions_without_sandbox_backend
{
    return match approval_policy {
        AskForApproval::Never => Decision::Forbidden,
        AskForApproval::OnRequest
        | AskForApproval::UnlessTrusted
        | AskForApproval::Granular(_) => Decision::Prompt,
    };
}
```

其中 `windows_managed_fs_restrictions_without_sandbox_backend` 是一个特殊兜底：Windows 上沙箱后端被禁用（`WindowsSandboxLevel::Disabled`）却仍配置了受限文件系统策略时，**没有真实的平台沙箱来兑现策略形状**，此时必须保守处理，绝不静默放行。

结论一句话：

```text
危险命令（或无沙箱保护）+ Never → Forbidden
危险命令（或无沙箱保护）+ 其他策略 → Prompt（宁可询问，也不擅自封禁）
```

**普通命令：审批策略 × 沙箱的决策表。** 对应代码：

```rust
match approval_policy {
    // Never：依赖沙箱保护直接放行
    AskForApproval::Never => Decision::Allow,

    // UnlessTrusted：不可信项目里，未被显式规则放行的命令都要问
    AskForApproval::UnlessTrusted => Decision::Prompt,

    // OnRequest / Granular：看文件系统沙箱类型
    AskForApproval::OnRequest => match file_system_sandbox_policy.kind {
        FileSystemSandboxKind::Unrestricted | FileSystemSandboxKind::ExternalSandbox => Allow,
        FileSystemSandboxKind::Restricted => {
            if sandbox_permissions.requests_sandbox_override() {
                Decision::Prompt   // 命令主动申请升级沙箱权限 → 要问
            } else {
                Decision::Allow    // 不越界 → 沙箱内直接跑，不打扰用户
            }
        }
    },
    ...
}
```

翻译成表格：

| 审批策略                 | 文件系统沙箱                   | 是否请求沙箱升级 | fallback 决策           |
| ------------------------ | ------------------------------ | ---------------- | ----------------------- |
| `Never`                  | 任意                           | —                | `Allow`（依赖沙箱保护） |
| `UnlessTrusted`          | 任意                           | —                | `Prompt`                |
| `OnRequest` / `Granular` | Unrestricted / ExternalSandbox | —                | `Allow`                 |
| `OnRequest` / `Granular` | Restricted                     | 否               | `Allow`（沙箱内执行）   |
| `OnRequest` / `Granular` | Restricted                     | 是               | `Prompt`                |

所以：**普通命令可以完全不弹框地执行，但通常依然被关在沙箱里**——"不需要审批"不等于"裸奔"。

---

## 危险命令的识别

**入口分发与返回值。** 危险检查的入口是 `dangerous_command_match_for_origin`（`core/src/exec_policy.rs`），按命令来源分派：

```rust
match command_origin {
    ExecPolicyCommandOrigin::Generic => {
        dangerous_command_match_for_platform(command, command_platform)
    }
    ExecPolicyCommandOrigin::PowerShell => {
        dangerous_powershell_words_match(command, command_platform)
    }
}
```

返回值的语义（定义于 [`shell-command/src/command_safety/is_dangerous_command.rs`](codex-rs/shell-command/src/command_safety/is_dangerous_command.rs)）：

```rust
Some(DangerousCommandMatch::ForcedRm)  // 检测到强制删除类危险模式
Some(DangerousCommandMatch::Other)     // 检测到其他危险模式
None                                   // 未检测到分类器定义的危险模式
```

**递归检查的顺序与深度上限。** `dangerous_command_match_with_depth`（`is_dangerous_command.rs:49`）按如下顺序推进：

```text
1. 检查包装递归深度是否超限
2. 检查当前命令本身（rm / sudo / env / trap）
3. 解析 sh -c / bash -lc 字面量里的嵌套命令，递归检查
4. Windows 下执行 Windows 专用检查
5. 都没有命中 → None
```

当包装深度超过 `MAX_DANGEROUS_COMMAND_WRAPPER_DEPTH = 8`（`is_dangerous_command.rs:34`）时，代码**保守地返回 `Some(Other)`**——宁可误报，也不放过层层套娃的命令。

**当前命令本身：rm / sudo / env / trap。** `dangerous_command_match_for_exec`（`is_dangerous_command.rs:123`）重点关注四类：

- **`rm` 携带 force 选项**：`rm_args_include_force_option`（`:196`）识别 `rm -f`、`rm -rf`、`rm -fr`、`rm --force` 等变体，返回 `ForcedRm`；
- **`sudo` 包装**：剥掉 `sudo` 递归检查真正要执行的命令；
- **`env` 包装**：跳过 `KEY=value` 与 `--` 等参数后递归检查实际命令；
- **`trap`**：trap 的动作本质是 shell 源码，需要按字面量递归检查。

一个细节：`rm_args_include_force_option` 只在 `--` 之前扫描选项，所以

```bash
rm -f file        # 危险
rm -rf directory  # 危险
rm --force file   # 危险
rm -- -f weird    # -- 之后的 token 不再被当作选项
```

**嵌套 shell 里的字面量命令。** 检查器通过 `parse_shell_lc_literal_commands`（[`shell-command/src/bash.rs:136`](codex-rs/shell-command/src/bash.rs)）抽取 `sh -c`、`bash -lc` 等包装中**字面量可见**的命令，并对控制流、命令替换里的内容一并递归检查：

```bash
bash -lc "echo hello; rm -rf /data"   # 内层 rm -rf 被检出 → 整体危险
```

需要强调：**这不是完整的 shell 解释器**，而是针对字面量命令的有限解析；动态拼接、运行时才产生的命令不在静态检查范围内——这正是沙箱存在的意义。

**Windows 专用检查。** 实现位于 `shell-command/src/command_safety/windows_dangerous_commands.rs`，覆盖：

- PowerShell：`Start-Process`、`Invoke-Item`、`ShellExecute` 风格入口、`mshta`、`Remove-Item -Force`，以及带 URL 的启动（token 扫描是 best-effort，不是完整 PowerShell parser）；
- `cmd.exe`：`start URL`、`del /f`、`erase /f`、`rd /s /q`、`rmdir /s /q`，还处理了 `echo hi&del` 这类被连接符拼在一起的命令段；
- `explorer`、`mshta`、`rundll32 url.dll,fileprotocolhandler` 或浏览器可执行文件携带 URL 的启动。

**危险检查如何影响决策。** 危险分类器的**具体子类不直接决定三态**，它提供的是"是否危险"这个事实：

```text
dangerous_command_match = None    → 继续按审批策略 + 沙箱判断
dangerous_command_match = Some(..) → Never → Forbidden；其他策略 → Prompt
```

子类的差异主要体现在**拒绝文案**上（`core/src/exec_policy.rs:1115` 附近）：

```text
ForcedRm → "rm -f style commands are not permitted. Use a safer approach"
Other    → "blocked by policy"
```

---

## 审批、沙箱与升级重试

**`ExecApprovalRequirement`：决策到编排的接口。** 它定义在 `core/src/tools/sandboxing.rs:152`，是"策略结论"与"执行编排"之间的接口：

```rust
pub(crate) enum ExecApprovalRequirement {
    /// 无需审批即可执行
    Skip {
        /// 首次尝试是否绕过沙箱（仅当被显式规则完全放行时可能为 true）
        bypass_sandbox: bool,
        proposed_execpolicy_amendment: Option<ExecPolicyAmendment>,
    },
    /// 需要用户审批
    NeedsApproval {
        reason: Option<String>,
        proposed_execpolicy_amendment: Option<ExecPolicyAmendment>,
    },
    /// 禁止执行
    Forbidden { reason: String },
}
```

**从 `Decision` 到三种状态。** 转换发生在 `create_exec_approval_requirement_for_parsed_commands`（[`exec_policy.rs:343`](codex-rs/core/src/exec_policy.rs)），核心是第 394 行起的 `match evaluation.decision`：

```text
Decision::Allow     → Skip
Decision::Prompt    → NeedsApproval；若审批策略禁止发起 prompt，则降级为 Forbidden
Decision::Forbidden → Forbidden（附带具体拒绝原因）
```

两个容易误读的点：

- **`Skip` 只表示"不需要用户审批"，不等于"绕过沙箱"**。`bypass_sandbox` 仅在**所有解析出的命令段都被显式规则允许**时才可能为 `true`（`exec_policy.rs`：`commands.iter().all(|command| ...)`）。只要有一段落入 heuristics fallback，首次尝试就仍走沙箱；
- **`Prompt` 并不保证一定会弹框**。`prompt_is_rejected_by_policy`（`exec_policy.rs`）会结合审批策略裁决；在 `Never`、或 `Granular` 关闭了对应审批类别时，`NeedsApproval` 会被替换成 `Forbidden`，并给出"拒绝原因"而非弹框。

另外还有 `default_exec_approval_requirement`（`sandboxing.rs`）作为工具自身未实现审批钩子时的兜底：`Never` 不问；`OnRequest`/`Granular` 仅在文件系统为 Restricted 时问；`UnlessTrusted` 总是问。

**orchestrator 的统一编排流程。** `core/src/tools/orchestrator.rs` 是所有 Tool（包括 bash）的"审批 + 沙箱选择 + 重试语义"的统一编排点，文件头注释一句话概括：

```text
approval → select sandbox → attempt → retry with escalated sandbox
```

主分支在 `orchestrator.rs:178` 附近：

```rust
match &requirement {
    ExecApprovalRequirement::Skip { .. } => {
        // 直接进入"选择沙箱 → 首次尝试"
    }
    ExecApprovalRequirement::Forbidden { reason } => {
        return Err(ToolError::Rejected(reason.clone()));
    }
    ExecApprovalRequirement::NeedsApproval { reason, .. } => {
        // 构造审批上下文，请求用户审批
        tool_ctx.session.request_approval(action, approval_ctx).await?;
        already_approved = true;
    }
}
```

**沙箱拒绝后的升级重试。** 如果首次执行返回 `SandboxErr::Denied`，`orchestrator.rs:322`起会依次检查：

- 工具是否允许失败后升级（`escalate_on_failure`）；
- 当前审批策略是否允许无沙箱/更高权限的审批（`wants_no_sandbox_approval`）——**`Never` 与普通 `OnRequest` 场景下不重试**，直接把 Denied 结果返回给模型；
- 是否只是**网络访问被拒**（此时若有网络审批上下文，可针对该 host 发起专用审批）；
- 是否已经获得批准（`already_approved` / 审批缓存）；
- 是否需要再次调用 `session.request_approval(...)`。

通过检查后，orchestrator 会用更宽松的沙箱策略（甚至无沙箱）**重试一次**；重试前的审批提示会带上 `retry_reason`（如 "Network access to X is blocked by policy." / 沙箱拒绝原因），让用户明白为什么刚才失败、现在要什么。模块注释里那句 "no re-approval thanks to caching" 则点明了审批缓存的作用——同一回合内已批准的请求不会反复打扰用户。

---

## 审批策略与 yes/no 交互

**`AskForApproval`：四种审批策略。** 主要取值：

| 取值            | 语义                                                        |
| --------------- | ----------------------------------------------------------- |
| `OnRequest`     | （默认）需要时询问；普通命令在受限沙箱内可不问              |
| `UnlessTrusted` | 项目被标记为不可信时，凡未被显式规则放行的命令一律要求审批  |
| `Granular(...)` | 细粒度开关，分别控制"规则类 prompt"与"沙箱升级类审批"等类别 |
| `Never`         | 从不询问用户；无法在当前权限边界内安全执行时直接失败        |

`GranularApprovalConfig`（`protocol.rs:1010`）细分了五类审批开关：`sandbox_approval`（shell 命令的沙箱升级/附加权限请求）、`rules`（execpolicy `prompt` 规则触发的审批）、`skill_approval`、`request_permissions`、`mcp_elicitations`。

需要再次强调的反直觉点：**`Never` ≠ 所有命令都放行**。

```text
普通命令 + 当前沙箱足够  → 继续执行
危险命令 / 命中 prompt   → 直接失败（不弹框）
命中 forbidden          → 直接失败
```

`Never` 只是"不弹框"，安全边界交给沙箱；越界或危险的行为会被静默拒绝。

**core 侧：发起审批请求。** core 通过 `Session::request_command_approval` 发起审批，位于 `core/src/session/mod.rs:2626`，流程：

1. 为本次审批创建 **oneshot channel**（`tx_approve` / `rx_approve`）；
2. 把 sender 以审批 ID 注册进当前 turn 的 **pending approvals** 表；
3. 构造 `ExecApprovalRequestEvent`（携带命令、cwd、原因、可用的决策集合 `available_decisions` 等）；
4. 发送 `EventMsg::ExecApprovalRequest` 事件（TUI / 其他前端订阅该事件渲染审批面板）；
5. 异步等待 receiver 返回 `ReviewDecision`。

**TUI 侧：选项如何变成决策。** 审批面板在 tui/src/bottom_pane/approval_overlay.rs：

- `handle_exec_decision`处理用户选择，把命令类选择映射成 `ReviewDecision`（`command_decision_to_review_decision`）；
- 随后调用 `app_event_tx.exec_approval(thread_id, id.to_string(), decision)`（`:403`）把决策发回 core；
- 选项文案由 `exec_options`（`:840` 起）按 `available_decisions` 生成，典型如：

```text
Yes, proceed
Yes, just this once
Yes, and don't ask again for commands that start with `<prefix>`   ← 提议持久化为新 prefix_rule
Yes, and don't ask again for this command in this session          ← 写入本会话审批缓存
No, continue without running it
No, and tell Codex what to do differently                           ← 中断当前任务
```

**core 收到决策后做什么。** `core/src/session/handlers.rs:176` 的 `exec_approval` 处理回传决策：

- `Approved`：唤醒等待中的命令执行；
- `ApprovedForSession`：写入本会话的审批缓存，后续相同请求不再询问；
- `ApprovedExecpolicyAmendment`：先通过 `persist_execpolicy_amendment` **持久化新的 allow 规则**（失败仅告警不阻断），再批准本次执行；
- `NetworkPolicyAmendment`：写入针对某个 host 的 allow/deny 网络规则；
- `Denied`：不执行命令，但会话继续，模型会收到"用户拒绝"的结果；
- `Abort`：中断当前整个任务（对应 "tell Codex what to do differently"）。

---

## 沙箱：第二道边界

**审批与沙箱的分工**：

```text
审批机制回答：允不允许执行这个请求？
沙箱机制回答：即使执行，它最多能碰到哪些资源？
```

沙箱是对命令实际进程施加的**资源隔离边界**，限制命令可以：

- 读写哪些文件（尤其工作目录之外的部分）；
- 访问哪些网络；
- 占用哪些进程环境与系统资源。

**典型组合示例。** 命令完全可以同时满足：

```text
execpolicy       = Allow
approval         = Skip
filesystem sandbox = Restricted
network          = Denied
```

含义是：**不需要用户确认，但仍只能在受限文件系统中执行，网络访问会被阻止**。

**`FileSystemSandboxKind`。** 定义在 `protocol/src/permissions.rs`：

```rust
pub enum FileSystemSandboxKind {
    Restricted,      // 施加 Codex 自己的文件系统限制
    Unrestricted,    // 不施加 Codex 侧文件系统限制
    ExternalSandbox, // 边界由外部执行环境负责（如云端沙箱）
}
```

第 3 章中 fallback 对不同 kind 给出不同默认决策，正是因为这个字段直接决定了"静默放行是否安全"。

---

## 场景速查与总结

| 场景                                                   | 决策                          | 最终结果                                 |
| ------------------------------------------------------ | ----------------------------- | ---------------------------------------- |
| 普通命令，可在受限沙箱内运行                           | fallback `Allow`              | 不弹框，沙箱内执行                       |
| 显式 `prefix_rule(..., allow)`                         | `Allow`                       | 不弹框；所有段均显式放行时可绕过首次沙箱 |
| 命中 `prefix_rule(..., prompt)`                        | `Prompt`                      | 弹框审批                                 |
| 命中 prompt 且策略为 `Never` / `Granular` 关闭规则审批 | 降级为 `Forbidden`            | 直接拒绝                                 |
| 命中 `forbidden`                                       | `Forbidden`                   | 直接拒绝，不提供批准选项                 |
| 危险命令 + `OnRequest`                                 | fallback `Prompt`             | 弹框审批                                 |
| 危险命令 + `Never`                                     | fallback `Forbidden`          | 直接拒绝                                 |
| 沙箱内执行被 `Denied` 且允许升级                       | 初始可能 `Skip`               | 视策略再次审批后用更高权限重试           |
| 用户选择 "session approval"                            | `ApprovedForSession`          | 本会话内同类请求不再询问                 |
| 用户选择 "don't ask again for prefix"                  | `ApprovedExecpolicyAmendment` | 新规则持久化，未来同类命令直接放行       |

`Allow` / `Prompt` / `Forbidden` 有两个来源：

```text
显式来源：规则文件中的 prefix_rule(decision = ...)
隐式来源：未匹配任何规则时，由 core 依据危险命令检查 + 审批策略 + 沙箱计算出的 fallback
```

最终放行与否，是如下因素**叠加**的结果：

```text
① 命令是否匹配显式规则          ② 所有匹配规则中的最高严重级别
③ 未匹配时的危险命令 fallback    ④ AskForApproval 审批策略
⑤ 文件系统与网络沙箱             ⑥ 是否请求权限升级
⑦ 审批缓存与持久化的新规则
```

对应地，决策的走向可以收敛成一条主线：

```text
命中 prefix_rule      → 使用显式策略
未命中 prefix_rule    → 使用 fallback 作为安全默认值
得到 Allow            → 不需要用户审批，但不一定绕过沙箱
得到 Prompt           → 若审批策略允许，向用户发起 yes/no 审批
得到 Forbidden        → 直接拒绝，不再询问用户 
```