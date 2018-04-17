# KVO底层原理实现的模仿demo

## 已经实现功能
1. 链式属性添加KVO ```vc_addObserver:observerforKeyPath:```，如```keyPath```为```@"car.wheel.price"```。
2. 移除属性的KVO监听 ```vc_removeObserver:observerforKeyPath:```。

## 实现原理
详见我的博文[KVO底层原理小结.md](https://github.com/VincentZhangZhipeng/blog/blob/master/2018-4-15/KVO%E5%BA%95%E5%B1%82%E5%8E%9F%E7%90%86%E5%B0%8F%E7%BB%93.md)。