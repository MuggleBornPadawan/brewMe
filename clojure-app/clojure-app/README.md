# Clojure Application

This is a simple Clojure application set up using Leiningen.

## Features

- Basic Clojure application structure
- Simple greeting functionality
- Command line argument handling
- Unit tests included

## Running the Application

To run the application:

```bash
cd clojure-app/clojure-app
lein run
```

To run with a name argument:

```bash
lein run "Your Name"
```

## Building the Application

To build a standalone JAR file:

```bash
lein ring uberjar
```

## Testing

To run the tests:

```bash
lein test
```

## Project Structure

- `src/clojure_app/core.clj` - Main application source code 
- `test/clojure_app/core_test.clj` - Unit tests
- `project.clj` - Leiningen project configuration

## Dependencies

- Clojure 1.12.2