require 'json'

# Array string of valid operators
$operators = %w[+ - * / ** % DROP DUP SWAP ROT ROLL ROLLD == != > < >= <= <=> & | ^ IFELSE << >> ! ~ x TRANSP EVAL]

# Reads and processes a file containing stack operations
# @param input_path [String] input file path
# @return [Array] stack after processing all operations
def read_file(input_path)
  stack = []
  return nil unless File.exist?(input_path) 

           # Curly-Braced Blocks  |  Square-Bracketed Blocks  |  Double-Quoted Strings | Non-Special Character
  token_regex = /(\{(?:[^\{\}]+|\g<1>)*\}) | (\[(?:[^\[\]]+|\g<2>)*\]) | ("[^"]*") | ([^\s\[\]\{\}]+)/x

  File.readlines(input_path).each do |line|
    tokens = line.scan(token_regex).map { |m| m.compact.first }
    tokens.each do |token|
      if token.start_with?("'")
        stack.push(token[1..-1])
        next
      end
      begin
        next unless check_token(token)
        stack_deluxe(token, stack)
        end
      rescue 
      end
    end
  stack
end

# Main operation to process token 
# @param token [String] Current token to process
# @param stack [Array] Current stack 
def stack_deluxe(token, stack)

  if token.start_with?("'")
    stack.push(token[1..-1])
    return
  end

  if token.start_with?('{') && token.end_with?('}')
    lambda_operator(token, stack)
    return
  end

  case token
  when '+', '*', '-', '/', '**', '%' then arithmetic_operator(token, stack)
  when 'DROP' then stack.pop if stack.any?
  when 'DUP' then stack.push(stack.last) if stack.any?
  when 'SWAP' then swap_operator(stack)
  when 'ROT' then rot_operator(stack)
  when 'ROLL', 'ROLLD' then roll_operator(stack, token)
  when '==', '!=', '>', '<', '>=', '<=', '<=>' then comparison_operator(token, stack)
  when '&', '|' then boolean_operator(token, stack)
  when 'IFELSE' then ifelse_operator(stack)
  when '<<', '>>', '^' then bitshift_operators(token, stack)
  when '!', '~' then unary_operators(token, stack)
  when 'x' then cross_operator(stack)
  when 'TRANSP' then transp_operator(stack)
  when 'EVAL'
    stack_deluxe(stack.pop, stack)
  else
    stack.push(token)
  end
end 

# Performs arithmetic operations on numeric values and strings
# @param operator [String] Arithmetic operator
# @param stack [Array] Stack contains operand 
def arithmetic_operator(operator, stack)
  return if stack.size < 2
  a = stack.pop 
  b = stack.pop 
  result =  if operator == '*'
              if check_token(b, 'matrix') && check_token(a, 'vector') then matrix_vector_multiply(b, a)
              elsif check_token(a, 'matrix') && check_token(b, 'matrix') then matrix_multiply(a, b)
              elsif check_token(a, 'array') && check_token(b, 'array') then array_operator(a, b, operator)
              elsif check_token(a, 'number') && check_token(b, 'string') then b * a.to_i
              else numeric_operator(b, a, operator).to_s
              end
            elsif operator == '+' then
              if check_token(a, 'array') && check_token(b, 'array') then array_operator(a, b, operator)
              elsif check_token(a, 'string') && check_token(b, 'string') then b + a
              else numeric_operator(b, a, operator).to_s
              end
            else numeric_operator(b, a, operator).to_s
            end
  stack.push(result)
end

# Swaps the top two elements of the stack
# @param stack [Array] Stack contains operand
def swap_operator(stack)
  return if stack.size < 2
  a, b = stack.pop(2)
  stack.push(b, a)
end

# Rotates the top three stack elements
# @param stack [Array] Stack contains operand
def rot_operator(stack)
  return if stack.size < 3
  elements = stack.pop(3)
  stack.push(*elements.rotate(1))
end

# Roll operation on stack elements
# @param stack [Array] Current stack state
# @param token [String] Token contains 'ROLL' or 'ROLLD'
def roll_operator(stack, token)
  return if stack.empty?
  n = stack.pop.to_i
  return if n < 0 || stack.size < n
  elements = stack.pop(n)
  rotated = token == 'ROLL' ? elements.rotate(1) : elements.rotate(-1)
  stack.push(*rotated)
end

# Comparison operation
# @param operator [String] Comparison operator
# @param stack [Array] Stack contains operand
def comparison_operator(operator, stack)
  return if stack.size < 2
  a = stack.pop
  b = stack.pop

  a_conv = check_token(a, 'number') ? parse_token(a, 'number') : a.to_s
  b_conv = check_token(b, 'number') ? parse_token(b, 'number') : b.to_s

  result = case operator
           when '==' then b_conv == a_conv
           when '!=' then b_conv != a_conv
           when '>'  then b_conv > a_conv
           when '<'  then b_conv < a_conv
           when '>=' then b_conv >= a_conv
           when '<=' then b_conv <= a_conv
           when '<=>' then b_conv <=> a_conv
           end
  stack.push(result)
end

# Boolean logic operation
# @param operator [String] Boolean operator 
# @param stack [Array] Stack contains operand
def boolean_operator(operator, stack)
  return if stack.size < 2
  a = parse_token(stack.pop, 'boolean')
  b = parse_token(stack.pop, 'boolean')
  result = case operator
           when '&' then b && a
           when '|' then b || a
           when '^' then b ^ a
           end
  stack.push(result)
end

# Ifelse conditional operation
# @param stack [Array] Stack contains operand
def ifelse_operator(stack)
  return if stack.size < 3
  condition = parse_token(stack.pop, 'boolean')
  a = stack.pop
  b = stack.pop
  result = condition ? b : a
  stack.push(result)
end

# Bitwise and shifts operation
# @param operator [String] Bitwise operator 
# @param stack [Array] Stack contains operand
def bitshift_operators(operator, stack)
  return if stack.size < 2
  a = stack.pop
  b = stack.pop

  result = case operator
    when '^'
      if check_token(a, 'boolean') && check_token(b, 'boolean')
        a_val = parse_token(a, 'boolean')
        b_val = parse_token(b, 'boolean')

        b_val.public_send(operator.to_sym, a_val).to_s
      else
        b.to_i.public_send(operator.to_sym, a.to_i)
      end
    else
      b.to_i.public_send(operator.to_sym, a.to_i)
    end
  stack.push(result)
end

# Unary operation
# @param operator [String] Unary operator 
# @param stack [Array] Stack contains operand
def unary_operators(operator, stack)
  return if stack.empty?
  val = stack.pop
  result = case operator
    when '!'
      val_bool = !parse_token(val, 'boolean')
      val_bool.to_s
    when '~'
      num = val.to_i
      ~num
    end
  stack.push(result)
end

# Cross product operation
# @param stack [Array] Stack contains operand
def cross_operator(stack)
  b = stack.pop
  a = stack.pop

  a_array = a[1...-1].split(',').map(&:strip).map(&:to_i)
  b_array = b[1...-1].split(',').map(&:strip).map(&:to_i)

  return unless a_array.size == 3 && b_array.size == 3
  x_cross = numeric_operator(numeric_operator(a_array[1], b_array[2], '*'), numeric_operator(a_array[2], b_array[1], '*'), '-')
  y_cross = numeric_operator(numeric_operator(a_array[2], b_array[0], '*'), numeric_operator(a_array[0], b_array[2], '*'), '-')
  z_cross = numeric_operator(numeric_operator(a_array[0], b_array[1], '*'), numeric_operator(a_array[1], b_array[0], '*'), '-')
  result = [ x_cross, y_cross, z_cross ]
  stack.push(result)
end

# Transposes a matrix
# @param stack [Array] Stack contains operand
def transp_operator(stack)
  return if stack.empty?
  token = stack.pop

  return stack.push(token) unless check_token(token, 'matrix')
  matrix = parse_token(token, 'matrix')
  return stack.push(token) unless matrix.is_a?(Array) && matrix.all? { |row| row.is_a?(Array) }
  
  stack.push(matrix.transpose)
end

# Processes lambda expressions
# @param token [String] Lambda token 
# @param stack [Array] Stack contains operand
def lambda_operator(token, stack)
  return if !check_token(token, 'lambda')
  inner = token[1...-1].strip #  remove the bracket
  parts = inner.split("|", 2) 
  count_str, body = parts.map(&:strip) # remove whitespace 
  count = count_str.to_i

  return if count > stack.size
  
  index = count.times.map { stack.pop }.reverse

  body.split(/\s+/).each do |t| # split into token when there a whitespace 

    case t
    when /^x(\d+)$/
      i = t[1..-1].to_i # remove X 
      if index.length > i then stack.push(index[i])
      else stack.push(t)
      end
    when 'SELF'
      stack.push(token)
    else
      stack_deluxe(t, stack)
    end
  end
end

########################## Helper Method #####################################

# Validates token format and type
# @param token [String] Input token to validate
# @param type [String] (Optional parameter) Match data type 
# @return [Boolean] True if token is valid for type
def check_token(token, type = nil)
  return true unless token.is_a?(String)

  def check_operator(token) = !token.start_with?('"') && !token.end_with?('"') && $operators.include?(token)
  def check_number(token) = !!Float(token) rescue false
  def check_string(token) = token.match?(/\A"[^"]*"\z/)
  def check_boolean(token) = token.downcase == 'true' || token.downcase == 'false'
  def check_array(token) = token.start_with?('[') && token.end_with?(']') && !token.start_with?('[[')
  def check_matrix(token) = token.start_with?('[[') && token.end_with?(']]')
  def check_lambda(token) = token.start_with?('{') && token.end_with?('}')

  case type
  when 'operator' then check_operator(token)
  when 'number'   then check_number(token)
  when 'string'   then check_string(token)
  when 'boolean'  then check_boolean(token)
  when 'array', 'vector' then check_array(token)
  when 'matrix'   then check_matrix(token)
  when 'lambda'   then check_lambda(token)
  else
    check_operator(token) ||
    check_number(token) ||
    check_string(token) ||
    check_array(token) ||
    check_matrix(token) ||
    check_lambda(token) ||
    check_boolean(token) 
  end
end

# Converts token string to Ruby object
# @param token [String] Token to convert
# @param type [String] Conversion type
# @return [Object] Converted value
def parse_token(token, type)
  return token unless token.is_a?(String)
  begin
    case type
    when 'number' 
      if  token.match(/^-?\d+$/)
        token.to_i
      else 
        float_num = token.to_f
        float_num == float_num.to_i ? float_num.to_i : float_num
      end
    when 'string' 
      if token.start_with?('"') && token.end_with?('"')
        token[1...-1]
      else
        token
      end
    when 'boolean' then token.downcase == "true"
    when 'array', 'vector' 
      token[1...-1].split(',').map do |t|
        t = t.strip
        if check_token(t, 'number')
          parse_token(t, 'number')
        elsif check_token(t, 'boolean')
          parse_token(t, 'boolean')
        else
          t  # String
        end
      end
    when 'matrix' then parse_matrix(token)
    end
  rescue => e
    token 
  end
end 

# Converts Matrix string to 2D array
# @param token [String] Token to convert
# @return [Array<Array>] Converted Matrix
def parse_matrix(token)
  JSON.parse(token)
  rescue JSON::ParserError
    nil
end

# Helper method for numeric operations
# @param b [string] First operand
# @param a [string] Second operand
# @param operator [String] Operator 
# @return [Numeric] Result 
def numeric_operator(b, a, operator)
  a_num = parse_token(a, 'number')
  b_num = parse_token(b, 'number')
  if operator == "/"
    b_num.to_f / a_num.to_f
  else
    b_num.public_send(operator.to_sym, a_num)
  end
end

# Performs array operations
# @param a [Array] First array
# @param b [Array] Second array
# @param operator [String] Operator 
# @return [Array] Result
def array_operator(a, b, operator)
  a_array = parse_token(a, 'array')
  b_array = parse_token(b, 'array')
  result = a_array.zip(b_array).map { |x, y| array_token_operator(x, y, operator) }
  return operator == '*' ? result.reduce { |sum, val| array_token_operator(sum, val, '+') } : result
end

# Performs the token inside the array
# @param a [String] First token
# @param b [String] Second token
# @param operator [String] Operator 
# @return [Object] Result
def array_token_operator(a, b, operator)
  if check_token(a, 'number') && check_token(b, 'number')
    numeric_operator(b, a, operator)
  elsif check_token(a, 'string') && check_token(b, 'string') && operator.include?('+')
      b + a
  elsif check_token(a, 'string') && check_token(b, 'string') && operator.include?('*')
     b * a.to_i
  else
     a + b
  end
end

# Multiplies matrix by vector
# @param matrix [Array<Array>] 2D matrix
# @param vector [Array] 1D vector
# @return [Array] Result in 1D vector
def matrix_vector_multiply(b, a)
  matrix = parse_token(b, 'matrix')
  vector = parse_token(a, 'vector')

  return stack.push(matrix) unless matrix.is_a?(Array) && matrix.all? {|row| row.is_a?(Array)}
  return stack.push(vector) unless vector.is_a?(Array)
  return nil unless matrix.all? { |row| row.size == vector.size }
  
  matrix.map { |row| row.zip(vector).sum { |x,y| x * y } }
end

# Performs matrix multiplication
# @param a [Array<Array>] First matrix
# @param b [Array<Array>] Second matrix
# @return [Array<Array>] Result in matrix
def matrix_multiply(a, b)
  begin
    a_matrix = parse_matrix(a)
    b_matrix = parse_matrix(b)
    return stack.push(a_matrix) unless a_matrix.is_a?(Array) && a_matrix.all? {|row| row.is_a?(Array)}
    return stack.push(b_matrix) unless b_matrix.is_a?(Array) && b_matrix.all? {|row| row.is_a?(Array)}
    
    a_matrix.map { |row|
      b_matrix.transpose.map { |col|
        row.zip(col).sum { |x,y| x * y }
      }
    }
  rescue
    nil
  end
end

# Helper method for formatting output tokens
# @param token [String] Stack 
# @return [Object] Format to data type
def format(token)
  case token
  when String
    if check_token(token, 'number') then parse_token(token, 'number')
    elsif check_token(token, 'boolean') then parse_token(token, 'boolean')
    elsif $operators.include?(token) then token
    else "\"#{token.delete('"')}\""
    end
  when Array
    '[' + token.map { |e| format(e) }.join(', ') + ']'
  else
    token.to_s
  end
end
##############################################################################

base_dir = File.dirname(__FILE__)
input_file_arg = ARGV[0]

input_path = File.expand_path(input_file_arg, base_dir)

xyz = File.basename(input_path).match(/input-(\d{3})\.txt/)[1]

output_filename = "output-#{xyz}.txt"
output_path = File.join(base_dir, output_filename)

begin
  stack_result = read_file(input_path)
rescue
  stack_result = []
end

output_content = stack_result ? stack_result.map { |token| format(token) }.join("\n") : ""
File.write(output_path, output_content)