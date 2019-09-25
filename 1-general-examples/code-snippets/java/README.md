# Reusable Java code blocks

## Dependencies
- [Apache Ant](https://ant.apache.org/)
- [Apache Ivy](https://ant.apache.org/ivy/)
- Dependencies automatically pulled in at build time by Ivy:
    - [Unirest](http://kong.github.io/unirest-java/)
    - [Picocli](https://picocli.info/)

## Building
Run the following command inside the `java` directory:

```Shell
ant build
```

## Running
```Shell
java -jar code_blocks.jar [-i] [--help] -h=<host> [-pf=<pass_file>] -u=<user>
```

## Source files
- `code_blocks.java`: Source with code blocks examples
- `build.xml`: Ant build file
- `ivy.xml`: Ivy dependencies file
- `README.md`: this file