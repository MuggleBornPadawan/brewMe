(ns clojure-app.core
  (:gen-class))

(defn add-numbers
  "Add two numbers together"
  [a b]
  (+ a b))

(defn greet
  "Greet a person by name"
  [name]
  (str "Hello, " name "!"))

(defn -main
  "Main function for the Clojure application"
  [& args]
  (if (empty? args)
    (println "Hello, World!")
    (let [first-arg (first args)]
      (if (= first-arg "--help")
        (println "Usage: clojure-app [name]")
        (println (greet first-arg))))))
