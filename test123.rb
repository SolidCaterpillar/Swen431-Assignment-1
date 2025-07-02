#!/usr/bin/env ruby

class StackMachine
  attr_reader :stack
  
  def initialize(debug = false)
    @stack = []
    @debug = debug
  end
  
  def log(message)
    puts message if @debug
  end
  
  def run(input)
    lines = input.strip.split("\n")
    
    # Set initial stack from first line
    @stack = lines[0].split.map(&:to_i)
    log "Initial stack: #{@stack.inspect}"
    
    # Parse function from second line
    if lines[1] =~ /\{\s*(\d+)\s*\|\s*(.*)\}/
      function_id = $1
      function_body = $2
      log "Function #{function_id}: #{function_body}"
      
      # Main execution loop
      @recursive = true
      iteration = 1
      
      while @recursive
        log "\n==== Iteration #{iteration} ===="
        log "Stack before: #{@stack.inspect}"
        
        # Process function body
        @recursive = false
        process_tokens(function_body.split)
        
        log "Stack after: #{@stack.inspect}"
        iteration += 1
      end
      
      log "\nFinal result: #{@stack.last}"
      return @stack.last
    else
      raise "Invalid function format: #{lines[1]}"
    end
  end
  
  def process_tokens(tokens)
    i = 0
    while i < tokens.length
      token = tokens[i]
      log "Processing token: #{token}"
      log "  Stack before: #{@stack.inspect}"
      
      case token
      when /^\d+$/
        # Push number to stack
        @stack.push(token.to_i)
      when "*"
        # Multiply top two values
        b = @stack.pop
        a = @stack.pop
        @stack.push(a * b)
      when "+"
        # Add top two values
        b = @stack.pop
        a = @stack.pop
        @stack.push(a + b)
      when "-"
        # Subtract top value from second top value
        b = @stack.pop
        a = @stack.pop
        @stack.push(a - b)
      when "/"
        # Divide second top value by top value
        b = @stack.pop
        a = @stack.pop
        @stack.push(a / b)
      when "DUP"
        # Duplicate top value
        @stack.push(@stack.last)
      when "DROP"
        # Remove top value
        @stack.pop
      when "SWAP"
        # Swap top two values
        b = @stack.pop
        a = @stack.pop
        @stack.push(b)
        @stack.push(a)
      when "ROT"
        # Rotate top three values: a b c -> b c a
        c = @stack.pop
        b = @stack.pop
        a = @stack.pop
        @stack.push(b)
        @stack.push(c)
        @stack.push(a)
      when ">"
        # Greater than
        b = @stack.pop
        a = @stack.pop
        @stack.push(a > b ? 1 : 0)
      when "<"
        # Less than
        b = @stack.pop
        a = @stack.pop
        @stack.push(a < b ? 1 : 0)
      when "="
        # Equal
        b = @stack.pop
        a = @stack.pop
        @stack.push(a == b ? 1 : 0)
      when "SELF"
        # Push literal "SELF"
        @stack.push("SELF")
      when "IFELSE"
        # If-then-else operator
        false_branch = @stack.pop
        true_branch = @stack.pop
        condition = @stack.pop
        
        # Non-zero values are truthy
        result = (condition.is_a?(Integer) && condition != 0) || 
                 (condition.is_a?(String) && !condition.empty?) ? 
                 true_branch : false_branch
        
        @stack.push(result)
      when "EVAL"
        # Evaluate token from stack
        to_eval = @stack.pop
        
        if to_eval == "SELF"
          # Recursive call - we'll handle it by setting a flag
          @recursive = true
        elsif to_eval == "DROP"
          # Execute DROP command
          @stack.pop
        else
          raise "Unknown command to evaluate: #{to_eval}"
        end
      else
        # Handle variables and quoted tokens
        if token.start_with?("'")
          # Push literal without the quote
          @stack.push(token[1..-1])
        elsif token =~ /^x(\d+)$/
          # Variable reference, e.g., x0, x1
          index = $1.to_i
          if index < @stack.size
            @stack.push(@stack[index])
          else
            raise "Stack index out of bounds: #{token}"
          end
        else
          raise "Unknown token: #{token}"
        end
      end
      
      log "  Stack after: #{@stack.inspect}"
      i += 1
    end
  end
end

# Input from the problem
input = "1 5
{ 2 | x0 x1 * x1 1 - DUP 0 > SELF 'DROP ROT IFELSE EVAL}"

# Run the stack machine
interpreter = StackMachine.new(false)  # Set to true for debug output
result = interpreter.run(input)

# Print the result
puts result