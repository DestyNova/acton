
void $RAISE(B_BaseException e);

 
/*
  Exceptions hierarchy in Python 3.8 according to

  https://docs.python.org/3/library/exceptions.html

  BaseException
  +-- SystemExit
  +-- KeyboardInterrupt
  +-- GeneratorExit
  +-- Exception
  +-- StopIteration
  +-- StopAsyncIteration
  +-- ArithmeticError
  |    +-- FloatingPointError              ***
  |    +-- OverflowError
  |    +-- ZeroDivisionError
  +-- AssertionError
  +-- AttributeError
  +-- BufferError                          ***
  +-- EOFError
  +-- ImportError                          ***
  |    +-- ModuleNotFoundError             ***
  +-- LookupError           
  |    +-- IndexError
  |    +-- KeyError
  +-- MemoryError
  +-- NameError                            ***
  |    +-- UnboundLocalError               ***
  +-- OSError
  |    +-- BlockingIOError
  |    +-- ChildProcessError
  |    +-- ConnectionError
  |    |    +-- BrokenPipeError
  |    |    +-- ConnectionAbortedError
  |    |    +-- ConnectionRefusedError
  |    |    +-- ConnectionResetError
  |    +-- FileExistsError
  |    +-- FileNotFoundError
  |    +-- InterruptedError
  |    +-- IsADirectoryError
  |    +-- NotADirectoryError
  |    +-- PermissionError
  |    +-- ProcessLookupError
  |    +-- TimeoutError
  +-- ReferenceError                       ***
  +-- RuntimeError
  |    +-- NotImplementedError
  |    +-- RecursionError
  +-- SyntaxError                          ***
  |    +-- IndentationError
  |         +-- TabError
  +-- SystemError
  +-- TypeError                            ***
  +-- ValueError
  |    +-- UnicodeError
  |         +-- UnicodeDecodeError
  |         +-- UnicodeEncodeError
  |         +-- UnicodeTranslateError
  +-- Warning
  +-- DeprecationWarning
  +-- PendingDeprecationWarning
  +-- RuntimeWarning
  +-- SyntaxWarning
  +-- UserWarning
  +-- FutureWarning
  +-- ImportWarning
  +-- UnicodeWarning
  +-- BytesWarning
  +-- ResourceWarning
 
*/
