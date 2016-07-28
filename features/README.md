
We are using Cucumber for automated testing. Read more at the
following two links:

- [link1](https://en.wikipedia.org/wiki/Cucumber_(software))
- [link2](http://www.methodsandtools.com/tools/cucumber.php)

features/
    This is the features directory. The features directory Contains
    feature files, which all have a .feature extension. May contain
    subdirectories to organize feature files.

features/step_definitions
    This directory contains step definition files, which are Ruby code 
    and have a .rb extension.

features/support
    This directory contains supporting Ruby code. Files in support
    load before those in step_definitions, which makes it useful for
    such things as environment configuration (commonly done in a file
    called env.rb).
