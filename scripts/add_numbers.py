#!/usr/bin/env python3
import sys

def add_numbers(a, b):
    return a + b

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python add_numbers.py <number> <number>")
    else:
        try:
            num1 = int(sys.argv[1])
            num2 = int(sys.argv[2])
            result = add_numbers(num1, num2)
            print(f"The sum is: {result}")
        except ValueError:
            print("Both arguments must be integers.")