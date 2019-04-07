# CSCI 3366 Programming Languages

R. Muller

# A Compiler for MiniC

This directory contains OCaml source code implementing a simple compiler translating a clipped version of C to native code (in assembly language form) for the MIPS architecture. The compiler is a pedagogical tool in the above titled programming languages course. The subset of C embodied in minC includes 

- integer and boolean types and expressions;
- function definitions and calls;
- imperative features: assignment, branching, while-loops and printing.

```c
int iterativeFact(int m) {
  int answer;
  answer = 1;
  while (m > 0) {
    answer = answer * m;
    m = m - 1;
    }
  return answer;
}

int recursiveFact(int n) {
  if (n == 0)
    return 1;
  else
    return n * recursiveFact(n - 1);
}

int main() {
  print iterativeFact(6);
  print recursiveFact(6);
  return 0;
}
```

##### Usage

```bash
> cd src
> make
> ./mc file.mc
```

The above produces the MIPS assembly file `file.asm`. In the `test/` directory there is a copy of the Mars MIPS simulator. To run `file.asm` type

```bash
> cd src
> java -jar test/Mars4_5.jar file.asm
```

To run a small test system, type

```bash
> cd src
> ./test/test.sh
```

To clean up intermediate files, type

```bash
> cd src
> make clean
```

### Compiler Project

The miniC compiler is designed to be used as the basis of a two-part project, each part implementing two phases of the miniC compiler. The phases are as follows:

```

miniC pgm -> Lexer -> Parser -> Typechcker -> Name -> Lift -> Control -> Codegen -> MIPS pgm
   
```

Part 1 of the project involves the implementation of the `Name` and `Lift` modules. Part 2 of the project involves the implementation of the `Control` and `Codegen` modules. See the `README.md` files for details.