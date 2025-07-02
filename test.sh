#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test counter variables
passed=0
failed=0
skipped=0
total=0

# Clear previous results
> test_results.log

echo "Starting tests..."

# Loop through all input files from 001 to 260
for i in $(seq -f "%03g" 1 260); do
  input_file="input-${i}.txt"
  output_file="output-${i}.txt"
  expected_file="expected-${i}.txt"
  
  # Determine input path and output directory
  if [ -f "${input_file}" ]; then
    input_path="${input_file}"
    output_dir="."
  elif [ -f "input/${input_file}" ]; then
    input_path="input/${input_file}"
    output_dir="output"
  else
    continue  # Skip if input file not found in either location
  fi
  
  # Create output directory if needed
  mkdir -p "${output_dir}"
  
  # Run the Ruby script
  ruby ws.rb "${input_path}"
  
  # Post-process the output file
  if [ -f "${output_dir}/${output_file}" ]; then
    sed -i 's/\r$//' "${output_dir}/${output_file}"
    sed -i 's/[ \t]*$//' "${output_dir}/${output_file}"
    sed -i -e '$a\' "${output_dir}/${output_file}"
  else
    echo -e "${RED}Test case ${i}: ERROR (Output file not generated)${NC}"
    continue
  fi
  
  total=$((total+1))
  
  # Check if expected file exists
  if [ ! -f "expected/${expected_file}" ]; then
    echo -e "${YELLOW}Test case ${i}: SKIPPED (Expected file missing)${NC}"
    echo "Test case ${i}: SKIPPED (Expected file missing)" >> test_results.log
    skipped=$((skipped+1))
    continue
  fi
  
  # Compare output vs expected
  if diff -q --ignore-trailing-space "${output_dir}/${output_file}" "expected/${expected_file}" >/dev/null; then
    echo -e "${GREEN}Test case ${i}: PASSED${NC}"
    echo "Test case ${i}: PASSED" >> test_results.log
    passed=$((passed+1))
  else
    echo -e "${RED}Test case ${i}: FAILED${NC}"
    echo "Test case ${i}: FAILED" >> test_results.log
    echo "Differences:" >> test_results.log
    echo "----------------------" >> test_results.log
    echo "Expected:" >> test_results.log
    cat "expected/${expected_file}" >> test_results.log
    echo "----------------------" >> test_results.log
    echo "Generated:" >> test_results.log
    cat "${output_dir}/${output_file}" >> test_results.log
    echo "----------------------" >> test_results.log
    failed=$((failed+1))
    
    # Display differences
    echo "Differences for test case ${i}:"
    echo "----------------------"
    echo "Expected:"
    cat "expected/${expected_file}"
    echo "----------------------"
    echo "Generated:"
    cat "${output_dir}/${output_file}"
    echo "----------------------"
  fi
done

# Print summary
echo -e "\nTest Summary:"
echo -e "${GREEN}Passed: ${passed}${NC}"
echo -e "${RED}Failed: ${failed}${NC}"
echo -e "${YELLOW}Skipped: ${skipped}${NC}"
echo -e "Total: ${total}"

# Save summary to log
echo -e "\nTest Summary:" >> test_results.log
echo "Passed: ${passed}" >> test_results.log
echo "Failed: ${failed}" >> test_results.log
echo "Skipped: ${skipped}" >> test_results.log
echo "Total: ${total}" >> test_results.log
echo "Test results saved to test_results.log"