# KVO底层原理实现的模仿demo

## 已经实现功能
1. 链式属性添加KVO ```vc_addObserver:observerforKeyPath:```，如```keyPath```为```@"car.wheel.price"```。
2. 移除属性的KVO监听 ```vc_removeObserver:observerforKeyPath:```。

## 实现原理
