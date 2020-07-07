# Simple Chisel Specification

Alpha Version 0.1, by Shibo Chen, Updated 7/3/2020

---

## Table of Contents

- [Simple Chisel Specification](#simple-chisel-specification)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Installation](#installation)
  - [Abstraction](#abstraction)
  - [Bulk Connection](#bulk-connection)
  - [Interface](#interface)
    - [Auto-connection between different interfaces](#auto-connection-between-different-interfaces)

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

All modules need to implement `in` and `out` as I/O interface to indicate the input and output respectively. Ports in `in` and `out` do not have to be inputs or outputs only, for example, it can be a `ReadyIO` which outputs a `ready` bit. It represents a general idea of the data flow.

Simple Chisel uses a new `>>>` operator to bulk connect between two modules or Bundle.

```scala
moduleA >>> moduleB
/* This is equivalent to 
 foreach( port <- moduleA.out){ // for each port in A's output 
   moduleB.in.port := port // Connect it to B's input
 }
*/
bundle >>> module
/* This is equivalent to 
 foreach( port <- bundle){ // for each port in bundle
   module.in.port := port // Connect it to module's input
 }
*/

 module >>> bundle
/* This is equivalent to 
 foreach( port <- module.out){ // for each port in module's output 
   module.in.port := port // Connect it to bundle
 }
*/

`>>>` operator can be overloaded to all SimpleChisel data or port types.
```

## Interface

As the inital lauch, we created 4 standard connection interface between the modules:  

- 3 in-order IO interfaces: `TightlyCoupledIO`, `ValidIO`, `DecoupledIO`, and  
- 1 out-of-order IO interface: `OutOfOrderIO`

`TightlyCoupledIO` is a regular IO interface which you usually see in basic module designs.
User needs to take two control signal inputs `stall`, and `clear`, and implements corresponding behaviors.
User also needs to output one control signal `stuck` indicating it stucks at the current cycle. User can specify the number of stages in this module and our compiler will automatically check whether it meets the design

```scala
module A(val number_of_stages) extends Module with TightlyCoupledIO(number_of_stages){
  // Your code here
  when(ctrl.stall){
    // what happends while stalling
  }
  when(ctrl.clear){
    // what happends while clearing
  }

  ctrl.stuck := ...// when does the module sutck
}

module Datapath extends Module{
  val component_A = Module(new A(4)) // A module that takes 4 cycles
}
```

`ValidIO` is a very much like the `TightlyCoupledIO` with the only difference that `ValidIO` takes in a `valid` signal indicating the input data is valid and outputs a `valid` signal indicating the output is valid. Therefore there is no need to have another `stuck` signal. 

```scala
module B(val number_of_stages) extends Module with ValidIO(number_of_stages){
  // Your code here
  when(in.valid){
    // what happends while input is valid
  }
  when(ctrl.stall){
    // what happends while stalling
  }
  when(ctrl.clear){
    // what happends while clearing
  }

  out.valid := ...// when does the output becomes valid
}

module Datapath extends Module{
  val component_B = Module(new B(4)) // B module that takes 4 cycles
}
```

`DecoupledIO` is a very much like the one in Chisel, except for it is on the global level. For each `in` and `out`, it has a pair of `ready`, `valid` signals indicating whether the downstream modules are ready for new inputs, or the product from the upstream module is valid. Since it is decoupled, we donnot need any module-level control, and the number of stages become irrelevent under this context. Instead, we would provide parameters to config the number of buffers before and after the module. We would also check that the inputs and outputs control signals are indeed independent of each other so there is not deadlock concern.

```scala
module C(val prepending_buffer, val postpending_buffer) extends Module with DecoupledIO(prepending_buffer, postpending_buffer){
  // Your code here
  when(in.valid){
    // what happends while input is valid
  }
  when(out.ready){
    // what happends while downstream is ready
  }

  out.valid := ...// when does the output becomes valid
  in.ready := ...// when does the input becomes ready
}

module Datapath extends Module{
  val component_C = Module(new C(4,4)) // C has 4 buffers each at the beginning and the end of the module
}
```

`OutOfOrderIO` is a common I/O used in hardware design when there can be multiple outstanding requests. Since each may take different number of cycles, for the sake of performance, it can be completed out-of-order. `OutOfOrderIO` inherits the `DecoupledIO` but gives out the `request_ticket_number` and `response_ticket_number`.

```scala
module D(val number_of_outstanding_request) extends Module with OutOfOrderIO(number_of_outstanding_request){
  // Your code here
  when(in.valid){
    // what happends while input is valid
  }
  when(out.ready){
    // what happends while downstream is ready
  }

  out.valid := ...// when does the output becomes valid
  in.request_ticket_number := ...// what's the ticket number for the most recent request
  out.response_ticket_number := ...// what's the ticket number for the most recent completed request
  in.ready := ...// when does the input becomes ready
}

module Datapath extends Module{
  val component_D = Module(new D(5)) // C has max of 5 outstanding request
}
```

|   | in | out  | ctrl  | parameters|  
|---|---|---|---|---|
| TightlyConpledIO | n/a  | n/a  | input: `stall`, `clear`<br>output: `stuck`  | number of cycles|  
| ValidIO | input: `valid`  | output: `valid` | input: `stall`, `clear`  | number of cycles|  
| ReadyIO  | input: `valid` <br> output: `ready`  | input: `ready` <br> output: `valid`  |  n/a | size of prepending and post pending buffers|  
| OutOfOrderIO  | input: `valid` <br> output: `ready`, `request_ticket_number`  | input: `ready` <br> output: `valid`, `response_ticket_number`  |  n/a | number of most outstanding request

### Auto-connection between different interfaces

We now explain automatic connection between modules with different interface when connected with `>>>`.
|Producer   |TightlyCoupledIO(e)| ValidIO(f) | DecoupledIO(g) | OutOfOrderIO(h)|  
|---|---|---|---|---|  
|TightlyCoupledIO(a)|a.ctrl.stall := e.ctrl.stuck|f.in.valid := a.ctrl.stuck \| a.ctrl.stall|a.ctrl.stall := !g.in.ready<br> g.in.valid := a.ctrl.stall\| a.ctrl.stuck|a.ctrl.stall := !h.in.ready<br> h.in.valid := a.ctrl.stall\| a.ctrl.stuck| 
|ValidIO(b)|---|f.in.valid := b.out.valid<br> b.ctrl.stall := (existing_signals)\|f.ctrl.stall|g.in.valid := b.out.valid <br> b.ctrl.stall := !g.in.ready|h.in.valid := b.out.valid <br> b.ctrl.stall := !h.in.ready| 
|DecoupledIO(c)|c.out.ready := e.ctrl.stuck \| e.ctrl.stall |c.out.ready := f.ctrl.stall<br>f.in.valid := c.out.valid | c.out.ready := g.in.ready <br> g.in.valid := c.out.valid|c.out.ready := h.in.ready <br> h.in.valid := c.out.valid| 
|OutOfOrderIO(d)|d.out.ready := e.ctrl.stuck \| e.ctrl.stall|d.out.ready := f.ctrl.stall<br>f.in.valid := d.out.valid|d.out.ready := g.in.ready <br> g.in.valid := d.out.valid|d.out.ready := h.in.ready <br> h.in.valid := d.out.valid|  
