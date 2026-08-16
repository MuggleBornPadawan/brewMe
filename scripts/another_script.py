#!/usr/bin/env python3
"""
Another sample Python script demonstrating file handling and data processing.
This script processes a CSV-like data file and generates reports.
"""

import csv
import json
from datetime import datetime
from typing import List, Dict

def read_data_file(filename: str) -> List[Dict]:
    """Read data from a CSV file."""
    try:
        with open(filename, 'r') as file:
            reader = csv.DictReader(file)
            return list(reader)
    except FileNotFoundError:
        print(f"Error: File '{filename}' not found.")
        return []
    except Exception as e:
        print(f"Error reading file: {str(e)}")
        return []

def process_sales_data(data: List[Dict]) -> Dict:
    """Process sales data and generate summary."""
    if not data:
        return {"error": "No data to process"}
    
    total_sales = 0
    product_counts = {}
    dates = []
    
    for row in data:
        try:
            # Process each row
            amount = float(row.get('amount', 0))
            total_sales += amount
            
            product = row.get('product', 'Unknown')
            product_counts[product] = product_counts.get(product, 0) + 1
            
            date = row.get('date')
            if date:
                dates.append(date)
                
        except (ValueError, KeyError):
            continue
    
    return {
        "total_sales": total_sales,
        "product_count": len(product_counts),
        "products": product_counts,
        "date_range": f"{min(dates) if dates else 'N/A'} to {max(dates) if dates else 'N/A'}"
    }

def generate_report(data: List[Dict], output_file: str = None) -> str:
    """Generate a formatted report."""
    summary = process_sales_data(data)
    
    if "error" in summary:
        return f"Report generation failed: {summary['error']}"
    
    report = f"""
Sales Report - Generated on {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
================================================

Total Sales: ${summary['total_sales']:,.2f}
Number of Products: {summary['product_count']}

Product Breakdown:
"""
    
    for product, count in summary['products'].items():
        report += f"  - {product}: {count} items sold\n"
    
    report += f"\nDate Range: {summary['date_range']}"

    if output_file:
        try:
            with open(output_file, 'w') as file:
                file.write(report)
            report += f"\n\nReport saved to {output_file}"
        except Exception as e:
            report += f"\n\nError saving report: {str(e)}"
    
    return report

def main():
    """Main function demonstrating the script."""
    print("=== Data Processing Script ===")
    
    # Create a sample data file for demonstration
    sample_data = [
        {"date": "2023-01-15", "product": "Laptop", "amount": "1200.00"},
        {"date": "2023-01-16", "product": "Mouse", "amount": "25.00"},
        {"date": "2023-01-17", "product": "Keyboard", "amount": "75.00"},
        {"date": "2023-01-18", "product": "Laptop", "amount": "1200.00"},
        {"date": "2023-01-19", "product": "Mouse", "amount": "25.00"},
    ]
    
    # Write sample data to CSV file
    try:
        with open('sales_data.csv', 'w', newline='') as file:
            writer = csv.DictWriter(file, fieldnames=['date', 'product', 'amount'])
            writer.writeheader()
            writer.writerows(sample_data)
        print("Created sample sales_data.csv file")
    except Exception as e:
        print(f"Error creating sample file: {str(e)}")
        return
    
    # Process the data
    data = read_data_file('sales_data.csv')
    report = generate_report(data, 'sales_report.txt')
    
    print(report)

if __name__ == "__main__":
    main()