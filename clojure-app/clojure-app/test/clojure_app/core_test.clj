(ns clojure-app.core-test
  (:require [clojure.test :refer :all]
            [clojure-app.core :refer :all]))

(deftest test-add-numbers
  (testing "Adding two numbers"
    (is (= 5 (add-numbers 2 3)))
    (is (= 0 (add-numbers -1 1)))))

(deftest test-greet
  (testing "Greeting a person"
    (is (= "Hello, Alice!" (greet "Alice")))))