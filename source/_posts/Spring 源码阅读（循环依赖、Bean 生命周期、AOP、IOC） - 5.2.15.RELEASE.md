---
title: Spring 源码阅读（循环依赖、Bean 生命周期、AOP、IOC） - 5.2.15.RELEASE
categories:
  - 后端开发
  - Spring
tags:
  - Java
  - Spring
  - IOC
  - AOP
date: 2025-05-25 10:40:27
description:
cover: https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-01.png
---
# 循环依赖

## 执行原理
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-01.png)
**三级缓存：** 

* 第一级缓存：singletonObjects，用于保存实例化、注入、初始化完成的 bean 实例例； 
* 第二级缓存：earlySingletonObjects，用于保存实例化完成的 bean 实例例；
* 第三级缓存：singletonFactories，⽤于保存 bean 创建⼯工⼚，以便后面有机会创建代理对象

**执行流程：**

* 在第一层中，先去获取 A 的 Bean，发现没有就准备去创建一个，然后将 A 的代理工⼚厂放入“三级缓存”（这个 A 其实是一个半成品，还没有对里⾯的属性进⾏注入），但是 A 依赖 B 的创建，就必须先去创建 B；

* 在第二层中，准备创建 B，发现 B ⼜依赖 A，需要先去创建 A；

* 在第三层中，去创建 A，因为第一层已经创建了了 A 的代理工厂，直接从“三级缓存”中拿到 A 的代理理⼯厂，获取 A 的代理理对象，放入“二级缓存”，并清除“三级缓存”；

* 回到第二层，现在有了 A 的代理理对象，对 A 的依赖完美解决（这里的 A 仍然是个半成品），B 初始化成功； 5. 回到第一层，现在 B 初始化成功，完成 A 对象的属性注入，然后再填充 A 的其它属性，以及 A 的其它步骤（包括 AOP），完成对 A 完整的初始化功能（这里的 A 才是完整的 Bean）。

 * 将 A 放入“一级缓存”

## 源码走读
```java
@Service
public class lbwxxcBean2 {
    @Autowired
    private lbwxxcBean1 lbwxxcBean1;

    public void test2() {
    }
}
```
```java
@Service
public class lbwxxcBean2 {
    @Autowired
    private lbwxxcBean1 lbwxxcBean1;

    public void test2() {
    }
}
```
先创建两个 Bean
### 第一层
```java
public class DefaultListableBeanFactory extends AbstractAutowireCapableBeanFactory
		implements ConfigurableListableBeanFactory, BeanDefinitionRegistry, Serializable {
		
		......
		
	@Override
	public void preInstantiateSingletons() throws BeansException {
		if (logger.isTraceEnabled()) {
			logger.trace("Pre-instantiating singletons in " + this);
		}

		// Iterate over a copy to allow for init methods which in turn register new bean definitions.
		// While this may not be part of the regular factory bootstrap, it does otherwise work fine.
		List<String> beanNames = new ArrayList<>(this.beanDefinitionNames);

		// 触发所有非懒加载的实例对象
		for (String beanName : beanNames) {
			RootBeanDefinition bd = getMergedLocalBeanDefinition(beanName);
			if (!bd.isAbstract() && bd.isSingleton() && !bd.isLazyInit()) {
				if (isFactoryBean(beanName)) {
					Object bean = getBean(FACTORY_BEAN_PREFIX + beanName);
					if (bean instanceof FactoryBean) {
						FactoryBean<?> factory = (FactoryBean<?>) bean;
						boolean isEagerInit;
						if (System.getSecurityManager() != null && factory instanceof SmartFactoryBean) {
							isEagerInit = AccessController.doPrivileged(
									(PrivilegedAction<Boolean>) ((SmartFactoryBean<?>) factory)::isEagerInit,
									getAccessControlContext());
						}
						else {
							isEagerInit = (factory instanceof SmartFactoryBean &&
									((SmartFactoryBean<?>) factory).isEagerInit());
						}
						if (isEagerInit) {
							getBean(beanName);
						}
					}
				}
				else {
					getBean(beanName);
				}
			}
		}
	
	......
	
}
```

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-02.png)先进入实例化所有非懒加载的单例对象的方法 **preInstantiateSingletons**

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-03.png)
进入实例化 **lbwxxcBean1** 的流程

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-04.png)
进入 AbstractBeanFactory 的 getBean ，然后再进入 AbstractBeanFactory  的 doGetBean 方法

```java
/**
 * 核心方法：获取或创建指定名称的 Bean 实例
 * 
 * @param name 要获取的 Bean 名称
 * @param requiredType 返回的 Bean 必须匹配的类型（可以为 null）
 * @param args 创建 Bean 时使用的显式参数（可以为 null）
 * @param typeCheckOnly 是否仅进行类型检查而不创建 Bean
 * @return 返回指定类型的 Bean 实例
 * @throws BeansException 如果 Bean 创建失败
 */
protected <T> T doGetBean(
        String name, @Nullable Class<T> requiredType, @Nullable Object[] args, boolean typeCheckOnly)
        throws BeansException {

    // 将给定的 bean 名称转换为规范名称（处理别名、FactoryBean 前缀等）
    String beanName = transformedBeanName(name);
    Object bean;

    // 首先检查单例缓存中是否有手动注册的单例 Bean
    Object sharedInstance = getSingleton(beanName);
    if (sharedInstance != null && args == null) {
        if (logger.isTraceEnabled()) {
            if (isSingletonCurrentlyInCreation(beanName)) {
                logger.trace("返回单例 Bean '" + beanName + "' 的早期缓存实例，该实例尚未完全初始化 - 循环引用的结果");
            }
            else {
                logger.trace("返回单例 Bean '" + beanName + "' 的缓存实例");
            }
        }
        // 如果是 FactoryBean，则返回其创建的对象；否则直接返回实例
        bean = getObjectForBeanInstance(sharedInstance, name, beanName, null);
    }

    else {
        // 检查是否正在创建此原型 Bean 实例（检测循环引用）
        if (isPrototypeCurrentlyInCreation(beanName)) {
            throw new BeanCurrentlyInCreationException(beanName);
        }

        // 检查父 BeanFactory 中是否有此 Bean 定义
        BeanFactory parentBeanFactory = getParentBeanFactory();
        if (parentBeanFactory != null && !containsBeanDefinition(beanName)) {
            // 当前工厂没有找到 -> 检查父工厂
            String nameToLookup = originalBeanName(name);
            if (parentBeanFactory instanceof AbstractBeanFactory) {
                return ((AbstractBeanFactory) parentBeanFactory).doGetBean(
                        nameToLookup, requiredType, args, typeCheckOnly);
            }
            else if (args != null) {
                // 带参数委托给父工厂
                return (T) parentBeanFactory.getBean(nameToLookup, args);
            }
            else if (requiredType != null) {
                // 带类型委托给父工厂
                return parentBeanFactory.getBean(nameToLookup, requiredType);
            }
            else {
                return (T) parentBeanFactory.getBean(nameToLookup);
            }
        }

        // 如果不是仅进行类型检查，则标记该 Bean 已被创建（用于记录和依赖检查）
        if (!typeCheckOnly) {
            markBeanAsCreated(beanName);
        }

        try {
            // 获取合并后的 RootBeanDefinition（处理父类定义和子类覆盖）
            RootBeanDefinition mbd = getMergedLocalBeanDefinition(beanName);
            // 检查 Bean 定义的有效性，确保其可创建
            checkMergedBeanDefinition(mbd, beanName, args);

            // 处理当前 Bean 依赖的其他 Bean（depends-on 属性）
            String[] dependsOn = mbd.getDependsOn();
            if (dependsOn != null) {
                for (String dep : dependsOn) {
                    // 检查循环依赖
                    if (isDependent(beanName, dep)) {
                        throw new BeanCreationException(mbd.getResourceDescription(), beanName,
                                "'" + beanName + "' 和 '" + dep + "' 之间存在循环依赖关系");
                    }
                    // 注册依赖关系
                    registerDependentBean(dep, beanName);
                    try {
                        // 获取依赖的 Bean，确保其先被创建
                        getBean(dep);
                    }
                    catch (NoSuchBeanDefinitionException ex) {
                        throw new BeanCreationException(mbd.getResourceDescription(), beanName,
                                "'" + beanName + "' 依赖的 Bean '" + dep + "' 不存在", ex);
                    }
                }
            }

            // 根据 Bean 的作用域创建 Bean 实例
            if (mbd.isSingleton()) {
                // 创建单例 Bean（使用回调函数确保实例只创建一次）
                sharedInstance = getSingleton(beanName, () -> {
                    try {
                        return createBean(beanName, mbd, args);
                    }
                    catch (BeansException ex) {
                        // 异常处理：从单例缓存中移除可能已放入的实例
                        destroySingleton(beanName);
                        throw ex;
                    }
                });
                bean = getObjectForBeanInstance(sharedInstance, name, beanName, mbd);
            }

            else if (mbd.isPrototype()) {
                // 创建原型 Bean（每次请求都创建新实例）
                Object prototypeInstance = null;
                try {
                    // 原型 Bean 创建前的回调（用于记录创建状态）
                    beforePrototypeCreation(beanName);
                    prototypeInstance = createBean(beanName, mbd, args);
                }
                finally {
                    // 原型 Bean 创建后的回调（清除创建状态）
                    afterPrototypeCreation(beanName);
                }
                bean = getObjectForBeanInstance(prototypeInstance, name, beanName, mbd);
            }

            else {
                // 处理自定义作用域的 Bean
                String scopeName = mbd.getScope();
                if (!StringUtils.hasLength(scopeName)) {
                    throw new IllegalStateException("Bean '" + beanName + "' 未定义作用域");
                }
                Scope scope = this.scopes.get(scopeName);
                if (scope == null) {
                    throw new IllegalStateException("未为作用域名称 '" + scopeName + "' 注册 Scope");
                }
                try {
                    // 从作用域中获取 Bean 实例（如果不存在则创建）
                    Object scopedInstance = scope.get(beanName, () -> {
                        beforePrototypeCreation(beanName);
                        try {
                        	// 创建 Bean
                            return createBean(beanName, mbd, args);
                        }
                        finally {
                            afterPrototypeCreation(beanName);
                        }
                    });
                    bean = getObjectForBeanInstance(scopedInstance, name, beanName, mbd);
                }
                catch (IllegalStateException ex) {
                    throw new BeanCreationException(beanName,
                            "作用域 '" + scopeName + "' 当前线程不可用；如果打算从单例引用它，考虑为此 Bean 定义一个作用域代理",
                            ex);
                }
            }
        }
        catch (BeansException ex) {
            // Bean 创建失败后的清理工作
            cleanupAfterBeanCreationFailure(beanName);
            throw ex;
        }
    }

    // 检查创建的 Bean 实例是否符合所需类型，如果需要则进行类型转换
    if (requiredType != null && !requiredType.isInstance(bean)) {
        try {
            T convertedBean = getTypeConverter().convertIfNecessary(bean, requiredType);
            if (convertedBean == null) {
                throw new BeanNotOfRequiredTypeException(name, requiredType, bean.getClass());
            }
            return convertedBean;
        }
        catch (TypeMismatchException ex) {
            if (logger.isTraceEnabled()) {
                logger.trace("无法将 Bean '" + name + "' 转换为所需类型 '" +
                        ClassUtils.getQualifiedName(requiredType) + "'", ex);
            }
            throw new BeanNotOfRequiredTypeException(name, requiredType, bean.getClass());
        }
    }
    return (T) bean;
}
```
进入 AbstractAutowireCapableBeanFactory 的 doCreateBean 方法
```java
/**
 * 核心方法：创建 Bean 实例并完成初始化
 * 
 * @param beanName       Bean 的名称
 * @param mbd            合并后的 Bean 定义
 * @param args           创建 Bean 时使用的构造函数参数（如果有）
 * @return               完全初始化后的 Bean 实例
 * @throws BeanCreationException 如果 Bean 创建失败
 */
protected Object doCreateBean(String beanName, RootBeanDefinition mbd, @Nullable Object[] args)
        throws BeanCreationException {

    // 步骤1：实例化 Bean
    BeanWrapper instanceWrapper = null;
    // 检查是否已有缓存的 FactoryBean 实例
    if (mbd.isSingleton()) {
        instanceWrapper = this.factoryBeanInstanceCache.remove(beanName);
    }
    // 如果没有缓存，则创建新的 Bean 实例
    if (instanceWrapper == null) {
        instanceWrapper = createBeanInstance(beanName, mbd, args);
    }
    Object bean = instanceWrapper.getWrappedInstance();
    Class<?> beanType = instanceWrapper.getWrappedClass();
    if (beanType != NullBean.class) {
        mbd.resolvedTargetType = beanType;
    }

    // 步骤2：应用合并 Bean 定义后置处理器
    // 允许 BeanPostProcessor 修改合并后的 Bean 定义（例如@Autowired注解处理）
    synchronized (mbd.postProcessingLock) {
        if (!mbd.postProcessed) {
            try {
                applyMergedBeanDefinitionPostProcessors(mbd, beanType, beanName);
            }
            catch (Throwable ex) {
                throw new BeanCreationException(mbd.getResourceDescription(), beanName,
                        "Post-processing of merged bean definition failed", ex);
            }
            mbd.postProcessed = true;
        }
    }

    // 步骤3：处理循环引用 - 提前暴露未完全初始化的 Bean
    boolean earlySingletonExposure = (mbd.isSingleton() && this.allowCircularReferences &&
            isSingletonCurrentlyInCreation(beanName));
    if (earlySingletonExposure) {
        if (logger.isTraceEnabled()) {
            logger.trace("Eagerly caching bean '" + beanName +
                    "' to allow for resolving potential circular references");
        }
        // 将 Bean 工厂添加到三级缓存中，允许提前获取 Bean 引用
        addSingletonFactory(beanName, () -> getEarlyBeanReference(beanName, mbd, bean));
    }

    // 步骤4：填充 Bean 属性并初始化 Bean
    Object exposedObject = bean;
    try {
        // 填充 Bean 的属性（依赖注入）
        populateBean(beanName, mbd, instanceWrapper);
        // 初始化 Bean（调用初始化方法和 BeanPostProcessor）
        exposedObject = initializeBean(beanName, exposedObject, mbd);
    }
    catch (Throwable ex) {
        if (ex instanceof BeanCreationException && beanName.equals(((BeanCreationException) ex).getBeanName())) {
            throw (BeanCreationException) ex;
        }
        else {
            throw new BeanCreationException(
                    mbd.getResourceDescription(), beanName, "Initialization of bean failed", ex);
        }
    }

    // 步骤5：处理循环引用的情况
    if (earlySingletonExposure) {
        Object earlySingletonReference = getSingleton(beanName, false);
        if (earlySingletonReference != null) {
            // 如果 Bean 在初始化过程中被代理，需要使用代理实例而非原始实例
            if (exposedObject == bean) {
                exposedObject = earlySingletonReference;
            }
            // 检查是否存在不允许的原始实例注入情况
            else if (!this.allowRawInjectionDespiteWrapping && hasDependentBean(beanName)) {
                String[] dependentBeans = getDependentBeans(beanName);
                Set<String> actualDependentBeans = new LinkedHashSet<>(dependentBeans.length);
                for (String dependentBean : dependentBeans) {
                    if (!removeSingletonIfCreatedForTypeCheckOnly(dependentBean)) {
                        actualDependentBeans.add(dependentBean);
                    }
                }
                if (!actualDependentBeans.isEmpty()) {
                    throw new BeanCurrentlyInCreationException(beanName,
                            "Bean 已以原始版本注入到其他 Bean 中，但最终被包装。" +
                            "这意味着其他 Bean 没有使用该 Bean 的最终版本。");
                }
            }
        }
    }

    // 步骤6：注册可销毁 Bean（如果需要）
    try {
        registerDisposableBeanIfNecessary(beanName, bean, mbd);
    }
    catch (BeanDefinitionValidationException ex) {
        throw new BeanCreationException(
                mbd.getResourceDescription(), beanName, "Invalid destruction signature", ex);
    }

    return exposedObject;
}
```

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-05.png)
然后调用 DefaultSingletonBeanRegistry 的 addSingletonFactory 方法，在这个方法中，将 lbwxxcBean1 的工厂放入三级缓存中

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-06.png)
进入 populateBean 方法进行依赖注入

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-07.png)
然后进入这个方法，这个方法是由策略模式和工厂模式组成的，进入其实现类

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-08.png)
然后进入 AutowiredAnnotationBeanPostProcessor 的 postProcessProperties 方法

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-09.png)
再然后进入AutowiredAnnotationBeanPostProcessor  的  resolveFieldValue 方法

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-10.png)
进入 DefaultListableBeanFactory 的 resolveDependency 的 doResolveDependency 中

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-11.png)
注入依赖 lbwxxcBean2

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-12.png)
获取 lbwxxcBean2 

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-13.png)
开始获取 lbwxxcBean2

从这里开始进入第二层

### 第二层
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-14.png)
第二层前面的逻辑跟第一层基本一致

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-15.png)
开始为 lbwxxcBean2 注入依赖 lbwxxcBean1

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-16.png)
尝试获取 lbwxxcBean1

第二层结束，进入第三层

### 第三层

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-17.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-18.png)
因为在第一层中，已将 lbwxxcBean1 的工厂放入到三级缓存中，因此在为 lbwxxcBean2 注入依赖时，可以找到 lbwxxcBean1 的工厂，所以删除三级缓存的工厂，将代理对象塞入二级缓存
最后 lbwxxcBean1 的代理对象，解决了 lbwxxcBean2 的依赖关系，返回第二层

### 返回第二层
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-19.png)
在创建完 lbwxxcBean2 后会进入 getSingleton 方法

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-20.png)
会进入 addSingleton 方法 
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-21.png)
在这个方法中，lbwxxcBean2 会删除2，3级缓存，将 lbwxxcBean2 放入 1级缓存中，到此为止第二层结束，lbwxxcBean2 初始化完成

### 返回第一层
lbwxxcBean2 初始完完成后会返回第一层

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-22.png)
lbwxxcBean1 也初始化完成，删除2，3级缓存，将 lbwxxcBean1 放入1级缓存中

## 总结
### 3 级缓存的作用
先说 “一级缓存” 作用，变量名为singletonObjects，结构是Map<String, Object>，它是单例池，将初始化好的对象存入，供其他线程使用。若无一级缓存，无法保证 Spring 单例属性。

直接看 “三级缓存”，变量名为singletonFactories，结构是Map<String, ObjectFactory<?>>，其Value是对象的代理工厂。三级缓存作用是存放对象的代理工厂，核心是通过工厂生成 “半成品单例 Bean” 以打破循环依赖。

eq：创建 A 时，将实例化的 A（未完成依赖属性 B 注入的半成品）通过代理工厂存入三级缓存。初始化 B 时需引用 A，此时通过三级缓存的工厂获取 A 的早期引用，从而打破循环。

为何三级缓存不直接存半成品 A，而存代理工厂？
因为涉及AOP。若 Bean 需要代理（如通过@Transactional等注解），代理工厂可在早期引用阶段动态生成代理对象，确保循环依赖中注入的是最终代理实例，而非原始对象。三级缓存通过工厂模式兼容了 **“原始对象” 和 “代理对象” 的创建逻辑**，保证 AOP 逻辑在循环依赖场景下正确应用。

对象工厂的作用：

* 如果 A 有 AOP，就创建一个代理理对象
* 如果 A 没有 AOP，就返回原对象

为什么不提前生成代理存入二级缓存？

AOP 代理的创建依赖于后置处理器（如 BeanPostProcessor），而后置处理器的执行时机是在 Bean 的初始化阶段（initializeBean 方法）。

在循环依赖场景中，Bean 可能仅完成实例化（未初始化），此时无法确定是否需要代理。因此，通过三级缓存的工厂延迟生成代理，可以在需要时动态决定是否创建代理，避免提前生成无效代理。
### 2 级缓存的作用
```java
@Service 
public class A {
	@Autowired 
	private B b;
	
	@Autowired 
	private C c;
	
	public void test1() {
	}
}
```

```java

@Service 
public class B {
	@Autowired 
	private A a;
	public void test2() {
	}
}
```
```java
@Service 
public class C {
	@Autowired 
	private A a;
	public void test3() {
	}
}
```
根据套娃逻辑，A 需依赖 B 和 C，但 B、C 均需依赖 A。
假设 A 需进行 AOP（代理对象每次生成不同实例），若仅保留一、三级缓存：

* B 获取 A 时，通过三级缓存的工厂生成代理对象 A1；
* C 获取 A 时，再次通过工厂生成代理对象 A2。

问题：两次生成不同实例（A1 ≠ A2），违背单例原则。

二级缓存作用：存储通过三级缓存工厂生成的半成品 AOP 代理对象（如 A1）。后续获取时直接从二级缓存取值，避免重复生成新代理对象。

结论：若无 AOP，仅需一、三级缓存即可解决循环依赖；若存在 AOP，必须通过二级缓存确保代理对象单例。


 3 级缓存的作用：
* 一级缓存：为“Spring 的单例例属性”⽽生，就是个单例池，⽤用来存放已经初始化完成的单例 Bean； 
* 二级缓存：为“解决 AOP”⽽生，存放的是半成品的 AOP 的单例 Bean；
* 三级缓存：为“打破循环”⽽生，存放的是生成半成品单例 Bean 的工⼚方法

三级缓存与二级缓存的协作逻辑：

场景：有 AOP 的循环依赖（A → B → A）
1. A 实例化：
	* A 完成实例化（未初始化和属性填充），将 ObjectFactory 存入三级缓存（工厂逻辑：若需要代理，生成代理对象；否则返回原始对象）。
	* 此时 A 是半成品，未注入依赖 B，也未创建代理。
2. B 初始化时引用 A：
	* B 需要注入 A，触发提前获取 A 的早期引用。
	* 从三级缓存获取工厂，调用工厂生成 A 的早期引用。由于 A 需要 AOP 代理，工厂生成代理对象 AProxy，并将其存入二级缓存（同时从三级缓存移除工厂）。
	* 将 AProxy 注入到 B 中，完成 B 的初始化。
3. A 继续初始化：
	* A 注入依赖 B（此时 B 已初始化完成），进入初始化阶段（执行后置处理器，创建最终的代理对象 AProxyFinal）。
	* 将最终的 AProxyFinal 存入一级缓存（singletonObjects），并清除二级缓存中的 AProxy（因二者本质是同一代理对象，无需保留早期引用）。
关键结论：
* 三级缓存的工厂负责动态生成对象（原始或代理），二级缓存负责缓存工厂的结果，避免重复生成。
* 若直接将代理对象存入二级缓存，会导致：
	* 无法处理 “无需代理” 的场景（提前生成无效代理）。
	* 循环依赖中可能因代理创建时机过早，导致后置处理器未执行（代理不完整）。


# Bean 生命周期
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-23.png)
## 理论基础
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-24.png)
Bean ⽣命周期过程：
* 实例化：第 1 步，实例例化一个 Bean 对象； 
* 属性赋值：第 2 步，为 Bean 设置相关属性和依赖； 
* 初始化：初始化的阶段的步骤比较多，5、6 步是真正的初始化，第 3、4 步为在初始化前执行，第 7 步在初始化后执行，初始化完成之后，Bean 就可以被使用了了；
* 销毁：第 8~10 步，第 8 步其实也可以算到销毁阶段，但不不是真正意义上的销毁，而是先在使用前注册了了销毁的相关调⽤接口，为了了后面第 9、10 步真正销毁 Bean 时再执行相应的方法

eq：代码示例
```java
@ToString
public class LbwxxcBean implements InitializingBean, BeanFactoryAware, BeanNameAware, DisposableBean {
    /**
     * 姓名
     */
    private String name;

    public LbwxxcBean() {
        System.out.println("1.调用构造方法：我出生了！");
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
        System.out.println("2.设置属性：我的名字叫"+name);
    }

    @Override
    public void setBeanName(String s) {
        System.out.println("3.调用BeanNameAware#setBeanName方法:我要上学了，起了个学名");
    }

    @Override
    public void setBeanFactory(BeanFactory beanFactory) throws BeansException {
        System.out.println("4.调用BeanFactoryAware#setBeanFactory方法：选好学校了");
    }

    @Override
    public void afterPropertiesSet() throws Exception {
        System.out.println("6.InitializingBean#afterPropertiesSet方法：入学登记");
    }

    public void init() {
        System.out.println("7.自定义init方法：努力上学ing");
    }

    @Override
    public void destroy() throws Exception {
        System.out.println("9.DisposableBean#destroy方法：平淡的一生落幕了");
    }

    public void destroyMethod() {
        System.out.println("10.自定义destroy方法:睡了，别想叫醒我");
    }

    public void work(){
        System.out.println("Bean使用中：工作，只有对社会没有用的人才放假。。");
    }
}

```

```java
public class MyTest {
    public static void main(String[] args) throws Exception {
        ApplicationContext context =new ClassPathXmlApplicationContext("classpath:applicationContext.xml");
        LbwxxcBean louzaiBean = (LbwxxcBean) context.getBean("lbwxxcBean");
        louzaiBean.work();
        ((ClassPathXmlApplicationContext) context).destroy();
    }
}
```
```xml
1.调用构造方法：我出生了！
2.设置属性：我的名字叫lbwxxc
3.调用BeanNameAware#setBeanName方法:我要上学了，起了个学名
4.调用BeanFactoryAware#setBeanFactory方法：选好学校了
5.BeanPostProcessor.postProcessBeforeInitialization方法：到学校报名啦
6.InitializingBean#afterPropertiesSet方法：入学登记
7.自定义init方法：努力上学ing
8.BeanPostProcessor#postProcessAfterInitialization方法：终于毕业，拿到毕业证啦！
Bean使用中：工作，只有对社会没有用的人才放假。。
started on Fri May 23 17:07:12 CST 2025
9.DisposableBean#destroy方法：平淡的一生落幕了
10.自定义destroy方法:睡了，别想叫醒我
```
整个生命周期有很多扩展过程，大致可以分为 4 类：

* Aware 接口：让 Bean 能拿到容器器的一些资源，例例如 BeanNameAware 的 setBeanName()， BeanFactoryAware 的 setBeanFactory()；
* 后处理器：进行一些前置和后置的处理理，例如 BeanPostProcessor 的 postProcessBeforeInitialization() 和 postProcessAfterInitialization()；
* 生命周期接口：定义初始化方法和销毁方法的，例例如 InitializingBean 的afterPropertiesSet()，以及 DisposableBean 的 destroy()；
* 配置生命周期方法：可以通过配置文件，自定义初始化和销毁方法，例例如配置文件配置的 init() 和 destroyMethod()。
## 源码走读
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-25.png)
实例化所有 bean 工程缓存的 bean 对象

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-26.png)
实例化 lbwxxcBean

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-27.png)
进入创建 Bean 的逻辑

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-28.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-29.png)
创建 Bean

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-30.png)
不需要特殊处理，直接通过无参的构造方法

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-31.png)
这段代码是Spring框架中`AbstractAutowireCapableBeanFactory`类的`instantiateBean`方法，负责**通过无参构造函数实例化Bean对象**。下面我将逐步解释其工作原理：

方法概述
`instantiateBean`方法是Spring Bean实例化的核心实现之一，它通过**无参构造函数**创建Bean实例，并将结果封装在`BeanWrapper`中返回。该方法不处理依赖注入，仅负责对象的创建。

 代码详细解析

 安全管理器检查
```java
if (System.getSecurityManager() != null) {
    beanInstance = AccessController.doPrivileged(
        (PrivilegedAction<Object>) () -> getInstantiationStrategy().instantiate(mbd, beanName, this),
        getAccessControlContext());
} else {
    beanInstance = getInstantiationStrategy().instantiate(mbd, beanName, this);
}
```
- **安全管理器**：Java的安全机制允许应用通过`SecurityManager`实施访问控制。
- **特权执行**：
  - 如果存在安全管理器，使用`AccessController.doPrivileged`在特权环境下执行实例化，避免权限不足异常。
  - 否则直接调用实例化策略。

实例化策略
```java
getInstantiationStrategy().instantiate(mbd, beanName, this)
```
- `InstantiationStrategy`是Spring的实例化策略接口，默认实现为：
  - **SimpleInstantiationStrategy**：普通Java反射（默认）。
  - **CglibSubclassingInstantiationStrategy**：支持方法覆盖（如`lookup-method`），使用CGLIB生成子类。
- `instantiate`方法通过**无参构造函数**创建Bean实例，不处理依赖注入。

 BeanWrapper封装
```java
BeanWrapper bw = new BeanWrapperImpl(beanInstance);
initBeanWrapper(bw);
return bw;
```
- **BeanWrapper**：Spring的属性访问和类型转换接口，封装了Bean实例，支持后续的属性注入。
- **初始化**：`initBeanWrapper`设置`ConversionService`和自定义`PropertyEditor`，为属性注入做准备。

异常处理
```java
catch (Throwable ex) {
    throw new BeanCreationException(
        mbd.getResourceDescription(), beanName, "Instantiation of bean failed", ex);
}
```
- 捕获所有异常，包装为`BeanCreationException`，提供详细的错误上下文（如Bean定义位置、名称）。

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-32.png)
创建实例

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-33.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-34.png)
这行代码就会调用 bean 的无参构造方法

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-35.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-36.png)
进行属性填充

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-37.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-38.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-39.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-40.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-41.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-42.png)
反射调用

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-43.png)
开始进行初始化

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-44.png)
```java
	protected Object initializeBean(String beanName, Object bean, @Nullable RootBeanDefinition mbd) {
		if (System.getSecurityManager() != null) {
			AccessController.doPrivileged((PrivilegedAction<Object>) () -> {
				invokeAwareMethods(beanName, bean);
				return null;
			}, getAccessControlContext());
		}
		else {
			invokeAwareMethods(beanName, bean);
		}

		Object wrappedBean = bean;
		if (mbd == null || !mbd.isSynthetic()) {
			wrappedBean = applyBeanPostProcessorsBeforeInitialization(wrappedBean, beanName);
		}

		try {
			invokeInitMethods(beanName, wrappedBean, mbd);
		}
		catch (Throwable ex) {
			throw new BeanCreationException(
					(mbd != null ? mbd.getResourceDescription() : null),
					beanName, "Invocation of init method failed", ex);
		}
		if (mbd == null || !mbd.isSynthetic()) {
			wrappedBean = applyBeanPostProcessorsAfterInitialization(wrappedBean, beanName);
		}

		return wrappedBean;
	}
```
这段代码是Spring框架中`AbstractAutowireCapableBeanFactory`类的`initializeBean`方法，负责**Bean的初始化阶段**，包括回调Aware接口、应用后置处理器、调用初始化方法等核心流程。它是Spring Bean生命周期管理的关键环节。


 **方法概述**
`initializeBean`方法的主要职责：
1. **回调Aware接口**（如`BeanNameAware`、`BeanFactoryAware`）。
2. **应用后置处理器**的初始化前处理（`postProcessBeforeInitialization`）。
3. **调用初始化方法**（如`afterPropertiesSet`、`@PostConstruct`）。
4. **应用后置处理器**的初始化后处理（`postProcessAfterInitialization`，如AOP代理生成）。


 **代码详细解析**

 **1. 回调Aware接口（`invokeAwareMethods`）**
```java
if (System.getSecurityManager() != null) {
    AccessController.doPrivileged((PrivilegedAction<Object>) () -> {
        invokeAwareMethods(beanName, bean);
        return null;
    }, getAccessControlContext());
} else {
    invokeAwareMethods(beanName, bean);
}
```
- **作用**：让Bean实例感知Spring容器的基础设施（如Bean名称、容器本身）。
- **常见Aware接口**：
  - `BeanNameAware`：注入当前Bean的名称（`setBeanName`）。
  - `BeanFactoryAware`：注入所属的`BeanFactory`（`setBeanFactory`）。
  - `ApplicationContextAware`：注入所属的`ApplicationContext`（`setApplicationContext`）。
- **安全管理器处理**：在安全环境下通过特权代码块执行，确保权限合法。


 **2. 应用后置处理器（初始化前）**
```java
wrappedBean = applyBeanPostProcessorsBeforeInitialization(wrappedBean, beanName);
```
- **核心逻辑**：
  - 遍历所有`BeanPostProcessor`，调用其`postProcessBeforeInitialization`方法。
  - 允许后置处理器修改Bean实例（如添加拦截器、修改属性）。
- **典型场景**：
  - **AOP前置处理**：部分后置处理器可能在此阶段为Bean生成代理（但AOP通常在初始化后处理）。
  - **自定义逻辑**：例如记录日志、验证Bean状态。


 **3. 调用初始化方法（`invokeInitMethods`**
```java
try {
    invokeInitMethods(beanName, wrappedBean, mbd);
} catch (Throwable ex) {
    throw new BeanCreationException(...);
}
```
- **处理逻辑**：
  - **JSR-250标准**：先调用`@PostConstruct`注解的方法（通过`CommonAnnotationBeanPostProcessor`）。
  - **Spring接口**：再调用`InitializingBean`接口的`afterPropertiesSet`方法。
  - **自定义初始化方法**：执行`bean.xml`中配置的`init-method`或`@Bean(initMethod = ...)`指定的方法。
- **异常处理**：包装初始化方法抛出的异常，提供清晰的错误上下文（如Bean名称、资源位置）。


 **4. 应用后置处理器（初始化后）**
```java
wrappedBean = applyBeanPostProcessorsAfterInitialization(wrappedBean, beanName);
```
- **核心逻辑**：
  - 遍历所有`BeanPostProcessor`，调用其`postProcessAfterInitialization`方法。
  - **关键扩展点**：Spring AOP的代理生成在此阶段完成（如`AnnotationAwareAspectJAutoProxyCreator`）。
- **返回值**：
  - 后置处理器可返回原始Bean或代理对象（如AOP代理），最终由容器使用返回的实例。


 **5. 合成Bean的特殊处理**
```java
if (mbd == null || !mbd.isSynthetic()) {
    // 执行后置处理器逻辑
}
```
- **合成Bean**：由Spring内部创建（非用户定义），如代理对象。
- **逻辑跳过**：合成Bean可能跳过部分后置处理器逻辑，避免不必要的处理。


 **关键细节**

1. **生命周期顺序**：
   ```
   实例化（构造函数） → 属性注入 → Aware接口回调 → 初始化前处理 → 初始化方法 → 初始化后处理
   ```
   - 初始化阶段发生在属性注入之后，是Bean可用前的最后一步。

2. **AOP代理生成时机**：
   - 初始化后处理阶段是Spring创建AOP代理的主要时机（通过`AbstractAutoProxyCreator`子类）。
   - 代理对象会替换原始Bean，后续依赖注入的是代理实例。

3. **扩展点优先级**：
   - `BeanPostProcessor`的执行顺序由其在容器中的注册顺序决定（可通过`@Order`或`Ordered`接口控制）。

4. **安全管理器影响**：
   - 特权代码块确保在受限环境下（如Applet、OSGi）仍能通过反射调用方法。


**总结**
`initializeBean`方法是Spring Bean生命周期的“最后一公里”，它：
1. 完成Bean与容器的基础设施对接（Aware接口）。
2. 提供了前置和后置的扩展点（`BeanPostProcessor`）。
3. 执行了初始化逻辑（注解、接口、自定义方法）。
4. 最终可能生成代理对象（如AOP增强）。

这种设计体现了Spring的**模板方法模式**，将固定流程（生命周期阶段）与可变行为（后置处理器、初始化逻辑）分离，既保证了框架的稳定性，又提供了高度的扩展性。

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-45.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-46.png)
执行自定义的后置方法

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-47.png)
这些方法会依次调用我们自定义的方法

## 总结
* doCreateBean()：这个是入口； 
* createBeanInstance()：⽤用来初始化 Bean，里面会调用对象的构造方法；
 * populateBean()：属性对象的依赖注⼊入，以及成员变量量初始化；
* initializeBean()：⾥面有 4 个方法，
	* 先执行 aware 的 BeanNameAware、BeanFactoryAware 接口； 
	* 再执行BeanPostProcessor 前置接口；
	* 然后执行 InitializingBean 接口，以及配置的 init()； 
	* 最后执行 BeanPostProcessor 的后置接口。
* destory()：先执行 DisposableBean 接口，再执行配置的 destroyMethod()

# AOP
## 理论基础
AOP 的全称是 “Aspect Oriented Programming”，即面向切面编程。

在 AOP 的思想里面，周边功能（比如性能统计，日志，事务管理理等）被定义为⾯面，核心功能和切面功能分别独立进行开发，然后把核心功能和切面功能“编织”在一起，这就叫 AOP

**AOP 基础概念：**

* 连接点(Join point)：能够被拦截的地方，Spring AOP 是基于动态代理理的，所以是方法拦截的，每个成员方法都可以称之为连接点；
* 切点(Poincut)：每个方法都可以称之为连接点，我们具体定位到某一个方法就成为切点； 
* 增强/通知(Advice)：表示添加到切点的一段逻辑代码，并定位连接点的方位信息，简单来说就定义了了是干什么的，具体是在哪干；
* 织入(Weaving)：将增强/通知添加到⽬目标类的具体连接点上的过程； 
* 引入/引介(Introduction)：允许我们向现有的类添加新方法或属性，是一种特殊的增强； 
* 切面(Aspect)：切⾯面由切点和增强/通知组成，它既包括了了横切逻辑的定义、也包括了了连接点的定义

**5 种通知的分类：**

* 前置通知(Before Advice)：在目标方法被调用前调用通知功能； 
* 后置通知(After Advice)：在目标方法被调用之后调用通知功能； 
* 返回通知(After-returning)：在目标方法成功执行之后调用通知功能； 
* 异常通知(After-throwing)：在目标方法抛出异常之后调用通知功能；
* 环绕通知(Around)：把整个目标方法包裹起来，在被调用前和调用之后分别调用通知功能

## 源码走读
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-48.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-49.png)

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-50.png)
创建 Bean

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-51.png)

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-52.png)
前置处理接口

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-53.png)
遍历所有 Bean

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-54.png)
生成 advice

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-55.png)
将切面缓存起来

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-56.png)
前置处理完成，将所有的切面缓存起来

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-57.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-58.png)
进入后置处理

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-59.png)
获取 lbwxxcBean 的切面列表

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-60.png)
创建代理对象

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-61.png)
通过 “责任链 + 递归”，执行切面和方法

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-62.png)
方法执行

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-63.png)
执行 everyday 的方法

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-64.png)
纯粹的责任链模式，对象内部有一个自身的 next 对象，执行完当前对象的方法末尾，就会启动 next 对象的执行， 直到最后一个 next 对象执行完毕，或者中途因为某些条件中断执行，责任链才会退出。

这⾥里里 CglibMethodInvocation 对象内部没有 next 对象，全程是通过 interceptorsAndDynamicMethodMatchers 长度为 3 的数组控制，依次去执行数组中的对象，直到最后一个对象执行完毕，责任链才会退出。

我们的主对象是 CglibMethodInvocation，继承于 ReflectiveMethodInvocation，然后 process() 的核心逻辑，其 实都在 ReflectiveMethodInvocation 中。
ReflectiveMethodInvocation 中的 process() 控制整个责任链的执行。
ReflectiveMethodInvocation 中的 process() 方法，里面有个⻓长度为 3 的数组 interceptorsAndDynamicMethodMatchers，里面存储了了 3 个对象，分别为 ExposeInvocationInterceptor、 MethodBeforeAdviceInterceptor、AfterReturningAdviceInterceptor

然后每次执行行 invoke() 时，里面都会去执行 CglibMethodInvocation 的 process()

**对象和方法的关系：**
* 接口继承：数组中的 3 个对象，都是继承 MethodInterceptor 接⼝口，实现里面的 invoke() 方法；
*  类继承：我们的主对象 CglibMethodInvocation，继承于 ReflectiveMethodInvocation，复⽤用它的 process() 方法；
* 两者结合（策略略模式）：invoke() 的入参，就是 CglibMethodInvocation，执行 invoke() 时，内部会执行 CglibMethodInvocation.process()，这个其实就是个策略略模式

**执行逻辑：**

* 程序入口：是 CglibMethodInvocation 的 process() ⽅方法； 
* 链式执行（衍生的责任链模式）：process() 中有个包含 3 个对象的数组，依次去执行每个对象的 invoke() 方法。
* 递归（逻辑回退）：invoke() 方法会执行切面逻辑，同时也会执行 CglibMethodInvocation 的 process() 方法，让逻辑再一次进⼊入 process()。
* 递归退出：当数字中的 3 个对象全部执行完毕，流程结束。

所以这里设计巧妙的地方，是因为纯粹责任链模式，里面的 next 对象，需要保证里面的对象类型完全相同。

但是数组里面的 3 个对象，里面没有 next 成员对象，所以不不能直接用责任链模式，那怎么办呢？就单独搞了了一个 CglibMethodInvocation.process()，通过去无限递归 process()，来实现这个责任链的逻辑

## 总结
* 将所有的切面都保存在缓存中； 
* 取出缓存中的切面列表，和l bwxxcBean 对象的所有方法匹配，拿到属于 lbwxxcBean 的切面列列表； 
* 创建 AOP 代理理对象；
* 通过“责任链 + 递归”，去执行切面逻辑


# 事务
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-65.png)
## 理论基础
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-66.png)
第一块是 **后置处理**，我们在创建 Louzai Bean 的后置处理器中，里面会做两件事情：

* 获取 Louzai 的切面方法：首先会拿到所有的切面信息，和 Louzai 的所有方法进行匹配，然后找到 Louzai 所有需要进行事务处理的方法，匹配成功的方法，还需要将事务属性保存到缓存 attributeCache 中
* 创建 AOP 代理对象：结合 Louzai 需要进行 AOP 的方法，选择 Cglib 或 JDK，创建 AOP 代理理对象。

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-67.png)
第二块是 **事务执行**，整个逻辑比较复杂，我只选取 4 块最核心的逻辑，分别为**从缓存拿到事务属性**、**创建并开启事务**、**执行业务逻辑**、**提交或者回滚事务**

## 源码走读
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-68.png)
进行初始化

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-69.png)
创建代理对象

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-70.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-71.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-72.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-73.png)
事务执行

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-74.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-75.png)
## 总结

* 先匹配出 louzai 对象所有关于事务的切面列列表，并将匹配成功的事务属性保存到缓存； 
* 从缓存取出事务属性，然后创建、启动事务，执行业务逻辑，最后提交或者回滚事务

# IOC
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-76.png)

## 基本原理


IOC 不不是一种技术，只是一种思想，一个重要的面向对象编程的法则，它能指导我们如何设计出松耦合、更更优良的程序。

传统应用程序都是由我们在类内部主动创建依赖对象，从⽽而导致类与类之间高耦合，难于测试。

有了 IOC 容器器后，把创建和查找依赖对象的控制权交给了了容器器，由容器器进行注入组合对象，所以对象与对象之间是松散耦合，便于测试和功能复用，整个体系结构更更加灵活。

理解 IOC 的关键是要明确 “谁控制谁，控制什什么，为何是反转（有反转就应该有正转了了），哪些⽅方⾯面反转了了”，我们浅析⼀一下：

* 谁控制谁，控制什么：
	* 传统 Java SE 程序设计，我们直接在对象内部通过 new 进行创建对象，是程序主动去创建依赖对象； 
	* IOC 是有专门一个容器器来创建这些对象，即由 IOC 容器器来控制对象的创建；
	* 谁控制谁？当然是 IOC 容器器控制对了象； 
	* 控制什什么？主要控制了了外部资源获取。 
* 为何反转，哪些方面反转：
	* 传统应用程序是由我们自己在对象中主动控制去直接获取依赖对象，也就是正转； 
	* 反转则是由容器器来帮忙创建及注入依赖对象；
	* 为何是反转？因为由容器器帮我们查找及注入依赖对象，对象只是被动的接受依赖对象，所以是反转； 
	* 哪些方面反转了？依赖对象的获取被反转了

ApplicationContext 接口是 BeanFactory 的子接口，也被称为 Spring 上下文，与 BeanFactory 一样，可以加载配置文件中定义的 bean，并进行管理理。

它还加强了了企业所需要的功能，如从属性文件中解析文本信息和将事件传递给所有指定的监视器器，下图是 ApplicationContext 接口的继承关系

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-77.png)
ApplicationContext 接口主要的 5 个作用如表所示：

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-78.png)
## 源码走读

```java
/**
 * 刷新此应用上下文，重建整个bean工厂。
 * 这是一个启动或重新启动应用上下文的核心方法，
 * 会销毁所有已创建的单例bean并重新创建它们。
 *
 * @throws BeansException      如果发生bean创建或查找错误
 * @throws IllegalStateException 如果上下文已被关闭或处于无效状态
 */
public void refresh() throws BeansException, IllegalStateException {
    // 使用同步锁确保在刷新过程中不会有其他线程干扰
    synchronized(this.startupShutdownMonitor) {
        // 准备刷新上下文环境，设置启动时间、标记为活跃状态并清除缓存
        this.prepareRefresh();
        
        // 获取一个全新的bean工厂实例，并加载bean定义
        ConfigurableListableBeanFactory beanFactory = this.obtainFreshBeanFactory();
        
        // 配置bean工厂的标准上下文特征，如类加载器、bean表达式解析器等
        this.prepareBeanFactory(beanFactory);

        try {
            // 允许子类对bean工厂进行后处理，例如注册特殊的bean处理器
            this.postProcessBeanFactory(beanFactory);
            
            // 执行所有已注册的BeanFactoryPostProcessor，允许修改bean定义
            this.invokeBeanFactoryPostProcessors(beanFactory);
            
            // 注册所有BeanPostProcessor，这些处理器会在bean初始化前后执行
            this.registerBeanPostProcessors(beanFactory);
            
            // 初始化用于国际化的MessageSource组件
            this.initMessageSource();
            
            // 初始化用于事件发布的应用事件多播器
            this.initApplicationEventMulticaster();
            
            // 由子类实现的模板方法，用于特定上下文的刷新操作
            this.onRefresh();
            
            // 注册应用监听器，这些监听器会接收应用发布的事件
            this.registerListeners();
            
            // 完成bean工厂的初始化，实例化所有剩余的非懒加载单例bean
            this.finishBeanFactoryInitialization(beanFactory);
            
            // 完成刷新过程，发布ContextRefreshedEvent事件
            this.finishRefresh();
        } catch (BeansException var9) {
            // 发生异常时记录警告信息
            if (this.logger.isWarnEnabled()) {
                this.logger.warn("Exception encountered during context initialization - cancelling refresh attempt: " + var9);
            }

            // 销毁已创建的所有bean，以避免资源泄漏
            this.destroyBeans();
            
            // 取消刷新操作，重置活跃状态
            this.cancelRefresh(var9);
            
            // 重新抛出异常，通知调用者刷新失败
            throw var9;
        } finally {
            // 重置Spring核心中的公共缓存，如反射元数据缓存
            this.resetCommonCaches();
        }
    }
}
```
refresh 是容器初始化的核心方法

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpring%20%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%EF%BC%88%E5%BE%AA%E7%8E%AF%E4%BE%9D%E8%B5%96%E3%80%81Bean%20%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E3%80%81AOP%E3%80%81IOC%EF%BC%89%20-%205.2.15.RELEASE-79.png)
## 总结



>https://mp.weixin.qq.com/s/10z1ELZleZ6kx1jqlsQ2xg












