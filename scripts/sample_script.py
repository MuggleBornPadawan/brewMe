#!/usr/bin/env python3
"""
Sample Python script demonstrating basic programming concepts.
This script shows functions, data structures, and error handling.
"""

import random
import sys

def generate_random_numbers(count: int, min_val: int = 1, max_val: int = 100) -> list:
    """Generate a list of random numbers."""
    return [random.randint(min_val, max_val) for _ in range(count)]

def calculate_statistics(numbers: list) -> dict:
    """Calculate basic statistics for a list of numbers."""
    if not numbers:
        return {"error": "Empty list provided"}
    
    return {
        "count": len(numbers),
        "sum": sum(numbers),
        "average": sum(numbers) / len(numbers),
        "min": min(numbers),
        "max": max(numbers)
    }

def process_data(data_list: list) -> str:
    """Process the data and return formatted string."""
    try:
        stats = calculate_statistics(data_list)
        
        if "error" in stats:
            return f"Error: {stats['error']}"
            
        return (f"Processed {stats['count']} numbers:\n"
                f"  Sum: {stats['sum']}\n"
                f"  Average: {stats['average']:.2f}\n"
                f"  Range: {stats['min']} to {stats['max']}")
                
    except Exception as e:
        return f"Error processing data: {str(e)}"

def main():
    """Main function to demonstrate the script."""
    print("=== Sample Python Script ===")
    
    # Generate random numbers
    numbers = generate_random_numbers(10)
    print(f"Generated numbers: {numbers}")
    
    # Process and display statistics
    result = process_data(numbers)
    print(result)
    
    # Show example of error handling
    print("\n--- Testing error handling ---")
    empty_result = process_data([])
    print(empty_result)

if __name__ == "__main__":
    main()