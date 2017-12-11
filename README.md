# RxDelphi
### Reactive programming on Delphi 

> Strongly recommend to read the book
>
> [![N|Solid](https://covers.oreillystatic.com/images/0636920042228/cat.gif)](http://shop.oreilly.com/product/0636920042228.do)

# Introduction
Documentation consists of next parts:

* [Tutorials](https://github.com/Purik/RxDelphi/blob/master/docs/Tutorials.md)
* [How-to guides](https://github.com/Purik/RxDelphi/blob/master/docs/HowToGuides.md)
* [Technical references](https://github.com/Purik/RxDelphi/blob/master/docs/TechReferences.md)

# Important to understand.


Reactive approach implementation for Delphi involves problem of reference counting for class instances. <b>RxDelphi</b> partially solves this problem by implementing <b>TSmartVariable</b> record that incapsulate automatic references counting and garbage collection, so developer can pass class instances to data streams, probably sheduled in separate threads.

But, auto references counting mechanism don't solve problem of simultenious access from separete threads. You have to solve this problem by Locks/Mutexes or, probably, by implementing immutable data structores (the simplest way to do it - simple copying).


### TODO
* GroupBy
* SubscribeOn 