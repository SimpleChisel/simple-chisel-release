# Simple Chisel Specification

Alpha Version 0.1, by Shibo Chen, Updated 7/3/2020

---

## Table of Contents

* [Introduction](#introduction)
* [Installation](#installation)
* [Abstraction](#abstraction)
* [Bulk Connection](#bulk-connection)
---

## Introduction

Simple Chisel is a description language at high level. It parses, converts and generates Chisel codes which work as a generator under the hood.

In this specification, we will discuss about the most revolutionary ideas introduced in Simple Chisel first and then introduces optimizations and simplifications we made upon Chisel.

We explore the idea of hardware polymorphism.

## Installation
To install SimpleChisel locally, first you need to get the submodule _simple-chisel_ which contains the language implementation.
```shell script
git submodule update --remote
cd simple-chisel
sbt publishLocal
```

All example codes is under another submodule. To run the examples, you need to first install _simple-chisel_ locally, and then run the following commands.
```shell script
cd simple-chisel-demo
make
```
## Abstraction
Simple Chisel introduces new abstractions `Logic` and `State`.

All `Logic` modules cannot contain any stateful elements, i.e. `Reg` and `Mem`. Any instance of `Logic` module needs to
be wrapped in `Logic()`

All `State` modules need to contain stateful elements. Any instance of `State` module needs to
be wrapped in `State()`

```scala
class LogicExample extends Logic{
  // Your code here
}

class StateExample extends State{
  // Your code here
}

class Datapth extends Module{
  val logicExample = Logic(new LogicExample)
  val stateExample = State(new StateExample)
}
```

## Bulk Connection
