# Simple Chisel Specification

Alpha Version 0.1, by Shibo Chen

---

## Table of Contents

* [Introduction](#introduction)
* [Ports](#ports)
  * [Parameterization](#parameterization)
  * [Connection](#connection)
  * [Bulk Connections](#bulk-connection)
* [Functionality Level Programming](#functionality-level-programming)
* [Component Level Programming](#component-level-programming)
  * [Fixed Ports Interface for Fast Integration](#fixed-ports-interface-for-fast-integration)
  * [High-level Abstractions](#high-level-abstractions)
* [Pipeline Level Programming](#pipeline-level-programming)
* [Data Types](#data-types)
  * [Casting](#casting)

---

## Introduction

Simple Chisel is a description language at high level. It parses, converts and generates Chisel codes which work as a generator under the hood.

In this specification, we will discuss about the most revolutionary ideas introduced in Simple Chisel first and then introduces optimizations and simplifications we made upon Chisel.

It's very important to keep in mind that Simple Chisel is a hardware description language and **NOT** a generator. Therefore, we can use the syntax out of the scope of scala. We can also use the same syntax with different semantics.

## Ports

Declaring ports in Chisel is clumpsy to some degree. Simple Chisel reservers the old way of declaring new ports for a module and provides a simpler way of doing it. In Simple Chisel, ports can be defined by defining arguments in the class constructor. We also simplify the verbose syntax to make it clearer and shorter.

As a comparison, assume we need to define a module `MyModule` with two input ports, one output port, and a flipped output port, all of which are of width 32.

In Chisel, it would look like this.

```scala
// MyModule and its ports implemented in Chisel.
class MyModule extends Module{
    val IO = new IO(new Bundle{
        val in1 = Input(UInt(32.W))
        val in2 = Input(UInt(32.W))
        val out = Output(UInt(32.W))
        val out_flip = flipped(Output(UInt(32.W)))
    })

    // Statements here
}
```

In Simple Chisel, instead, the ports definition would look much simpler.

```scala
// MyModule and its ports implemented in Simple Chisel.
class MyModule(
    in1: Input(32),
    in2: Input(32),
    out: Output(32),
    out_flip: flipped(Output(32))
) extends Module{
    // Statements here
}
```

### Parameterization

Let's take `MyModule` as an example. In this case, the width of input/output depends on the configuration where the width of input is of `n`, and the width of output is of `m`.

```scala
// MyModule and its ports implemented in Simple Chisel.
class MyModule(
    in1: Input(n),
    in2: Input(n),
    out: Output(m),
    out_flip: flipped(Output(m)))
    (n: UInt, m: UInt)
extends Module{
    // Statements here
}
```

You can instantiate the `MyModule` in other modules by calling

```scala
// Instantiate my module
val myModuleA = new MyModule()(N,M) // N and M are two integers

// Or instantiate my module
val myModuleB = new MyModule(i1,i2,o1,o2)(N,M)
```

### Connections

There are two ways to connect ports in Simple Chisel. One way is to connect ports during declaration (instatiation); the other way is to connect ports afterwards. We use the example above to demonstrate the two connection methods.

```scala
val i1 = 5.U(N)
val i2 = 6
val o1 = Bits(M)
val o2 = Bits(M)

// Connect the ports during instantiation
val myModuleB = new MyModule(i1,i2,o1,o2)(N,M)

// Or connect ports after instantiation
val myModuleA = new MyModule()(N,M) // N and M are two integers
myModuleA.in1 := i1
myModuleA.in2 := i2
o1 := myModuleA.out
myModuleA.out_flip := o2
```

### Bulk Connections

Bulk connection between ports can be done in two ways. One is the conventional Chisel way; the other way is connecting ports with a bundle of ports.

```scala
// MyModule and its ports implemented in Simple Chisel.
class MyModuleA(
    in1: Input(n),
    in2: Input(n),
    out: Output(m),
    out_flip: flipped(Output(m)))

class MyModuleB(
    in1: flipped(Input(n)),
    in2: flipped(Input(n)),
    out: flipped(Output(m)),
    out_flip: Output(m))

val myModuleA = new MyModuleA()
val myModuleB = new MyModuleB()

// To bulk connect A and B in the conventional way of Chisel
myModuleA <> myModuleB

// Or you can do
myModuleA <> new Bundle(myModuleB.in1, myModuleB.in2, myModuleB.out, myModuleB.out_flip)
```

## Functionality Level Programming

In Scala and Chisel, functions and methods are used to form reusable hardware components. While it does help with reusablity, it doesn't help much with simplicity and usability. If a single module has multiple functionalities, logics and gates would usually tangle up together, which makes it difficult to read and understand. One of the goals of Simple Chisel is to make codes readable and easy to maintain.

In order to do so, we use annotations to disentangle funcionalities in a module.

`@pipeline` is used to indicate that only one of the annotated cases will happen at a time. The compiler will reuse gates to implement different functions.

`@parallel` is used to indicate that one or more cases may happen at the same time. Simple Chisel will help generate dispatch logics and also corresponding interface.

We use a toy module `ALU` as an example to demonstrate this idea. The toy `ALU` can only do `add` and `sub`. In this example, `ALU` will be take in two operand inputs `in1` and `in2`, one function input `fn` and also one output port, `out`, for result.

```scala
// A pipeline ALU example
class ALU_pipeline(in1: Intput(32), in2: Intput(32),
        fn: Input(2), out: Output(32)){

        @pipeline
        def add() {
            if(fn === ADD){
                out := in1 + in2
            }
        }

        @pipeline
        def sub(){
            if(fn === SUB){
                out := in1 - in2
            }
        }
}

// A parallel ALU example
class ALU_parallel(in1: Intput(32), in2: Intput(32),
        fn: Input(2), out: Output(32)){

        @parallel
        def add() {
            if(fn === ADD){
                out := in1 + in2
            }
        }

        @parallel
        def sub(){
            if(fn === SUB){
                out := in1 - in2
            }
        }
}
```

The compiler will elaborate and convert the code above into Chisel compatible codes as below.

```scala
// After elaboration and conversion, the pipeline ALU would be like
class ALU_pipeline(in1: Intput(32), in2: Intput(32),
        fn: Input(2), out: Output(32)){

        out := Mux(fn === ADD, in1 + in2, Mux(fn === SUB, in1 - in2, 0))

}

// After elaboration and conversion, the parallel ALU would be like
class ALU_parallel(in1: Vec(2,Input(Bits(32))),
                   in2: Vec(2,Input(Bits(32))),
                   fn : Vec(2,Input(Bits(1))),
                   out: Vec(2,Output(Bits(32)))){

        out(1) := Mux(fn(1) === ADD, in1(1) + in2(1), Mux(fn(1) === SUB, in1(1) - in2(1), 0))
        out(2) := Mux(fn(2) === ADD, in1(2) + in2(2), Mux(fn(2) === SUB, in1(2) - in2(2), 0))
}
```

In the case above, the behavior of the module depends on the input `fn`. For cases that the parallel functions are independent of the input command, we simply omit the if statement in the function. 

```scala
// A parallel ALU example
class ALU_parallel(in1: Intput(32), in2: Intput(32), out: Output(32)){

        @parallel
        def add() {
                out := in1 + in2
        }

        @parallel
        def sub(){
                out := in1 - in2
        }
}

// After elaboration and conversion, the parallel ALU would be like
class ALU_parallel(in1: Vec(2,Input(Bits(32))),
                   in2: Vec(2,Input(Bits(32))),
                   out: Vec(2,Output(Bits(32)))){

        out(1) := in1(1) + in2(1)
        out(2) := in1(2) - in2(2)
}
```

For the case above, there are two sets of input. In order to bulk connect to the specific set of ports, we can specify it during the bulk connection.

```scala
val in1_add = Bits(32)
val in2_add = Bits(32)
val out_add = Bits(32)

val in1_sub = Bits(32)
val in2_sub = Bits(32)
val out_sub = Bits(32)

ALu_parallel.ADD <> new Bundle(in1_add, in2_add, out_add)
ALu_parallel.SUB <> new Bundle(in1_sub, in2_sub, out_sub)
```

## Component Level Programming

### Fixed Ports Interface for Fast Integration

What we found the flexibility given to the developer by most of the HDLs, while unnecessary at all, gives any person other than the developer a real headache to understand and modify the code.

A very representative case is the number of ports and the order of ports. Let's take memory as an easy example.

In a typical design, a SRAM memory would have a very different ports configuration with a FIFO queue even though their functionality is essentially the same: storing data.
For a SRAM memory block, it usually has `wr_data_in`, `wr_address_in`, `rd_address_in`, `rd_data_out`, `cmd_in` and additional ports for decoupling.
For a FIFO queue, ports would be different. A FIFO queue would not have ports for address. It would have `data_in`, `data_out`, `cmd_in` ports.

Now, let's think about one specific case in which the developer needs to change a SRAM memory block to a FIFO queue. Not only the developer needs to change the class of the memory block but also needs to rewire the ports. It's wouldn't be so difficult if the name of the ports are expressive or even have the same names. However, that's almost never the case. Developers usually need to understand a block very well in order to integrate it into the design which undermines the value of abstraction.

In Simple Chisel, we catagorize components into a few common classes. The compoments in each class would be forced to follow the convention which enforces the order of the ports and the number of the ports. In this case, FIFO queue would still need to have `wr_address_in` and `rd_address_in` ports even it doesn't need it.

At a higher level, the developer wouldn't need to do anything beside changing the class of the component.

```scala
// An SRAM block
class SRAM extends MEM{
    // Implementtion detals.
    // Ports are enforced
}

// A FIFO queue
class FIFO extends MEM{
    // Implementtion detals.
    // Ports are enforced
    // Unused ports would be dropped during the elaboration
}

val sram = new SRAM()
val fifo = new FIFO()

// Connect to sram
(data_in, w_addr_in, r_addr_in, r_dataa_out, cmd) <> sram

// Connect to FIFO, w_addr_in and r_addr_in only serve as place holder. It can be anything else.
(data_in, w_addr_in, r_addr_in, r_dataa_out, cmd) <> fifo
```

### High-level Abstractions

## Pipeline Level Programming

One of the headaches for lots of programmers is the lack of efficient abstraction of the pipeline stages. It's understandable that none of the HDLs today is providing pipleline level abstraction since it's not indispensible in all designs. Almost all HDLs would provide some kind of sequential logics (A.K.A. Reg) to implement pipeline. However, the lack of abstraction and separation makes debugging and changing the pipeline fundamentally hard.

The chanllage of providing such abstractions lies in the fact that different components may have different latency (# of cycles in synchronized circuits), which makes providing abstractions hard. To address this challenge, Simple Chisel provides an abstraction scheme such that the developer can easily connect the stages together and specify the number of cycles each stage will need.

```scala

// A stage in the pipeline
class StageOne(
    op1: Input(32,"decode"), // Input op1 comes from decode stage
    op2: Input(32,"dcache", data_out), // Input op2 comes from port data_out of decache stage
    out1: Output(32) // The output would be to the compute stage by default
) extends Stage{
    val stage_id = "compute" // Identifier of the stage. Different class can share the same id to indicate they are in the same stage

    def func(){
        // Functionalities of the current stage
    }
}

// Another stage in the pipeline
class StageTwo(
    addr: Input("compute",out1) // Input addr comes from the compute stage, port out1. The width can be inferred.
    data: Input(32, "dcache") // Input data comes from the dcahce stage
    out: Output(32)
) extends Stage{
    val stage_id = "mem_store"
    def func(){
        // Functionalities of the current stage
    }
}

// The pipeline of a design
class Pipeline(){
    val compute_stage = new StageOne()
    val mem_store_stage = new StageTwo()
}
```

In the example above, each output will be instantiated as a `Reg` which is synchronized to the clock. The connection will be automatically established wherever possible.

## Data Types

Data types of Simple Chisel are based on the original Chisel data types with simplifications. Since Simple Chisel is a description language, it doesn't necessarily override native scala data types.

In Simple Chisel, base types are the same as in Chisel. A raw collection of bits is represented by `Bits`. Signed and unsigned integers are represented by `SInt` and `UInt` respectively.

Literal values are expressed using integers. While not specified explicitly, values are assumed to be signed values. The width will be automatically infered.

```scala
1       // signed decimal 1-bit lit.
ha      // signed hexadecimal 4-bit lit.
o12     // signed octal 4-bit lit.
b1010   // signed binary 4-bit lit.

5.S     // signed decimal 4-bit lit from Scala Int.
-8.S    // negative decimal 4-bit lit from Scala Int.
5.U     // unsigned decimal 3-bit lit from Scala Int.

8.U(4)  // 4-bit unsigned decimal, value 8.
-152.S(32) // 32-bit signed decimal, value -152.

true    // Bool lits from Scala lits.
false
```

### Casting

Casting in Simple Chisel works the same as in Chisel but with simplications. `Clock` can't be cast to `Bool` directly and doesn't have to be converted to UInt first.
Examples:

```scala
// Casting between UInt and SInt
val sint = 3.S(4)               // 4-bit SInt
val uint = sint.asUInt          // cast SInt to UInt
uint.asSInt                     // cast UInt to SInt

//Casting between boolean type and clock
val bool = false                // always-low wire
val clock = bool.asClock        // always-low clock

clock.asUInt                    // convert clock to UInt (width 1)
clock.asBool                    // convert clock to Bool (Chisel 3.2+)
```
