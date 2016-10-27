record Token,
  type : Symbol, # :COMMAND_START, :COMMAND_END, :SEPERATOR, :LITERAL
  content : String

class Lexer
  @str : Array(Char)

  def initialize(string)
    @str = string.chars
    @pos = 0
    @finished = false
  end

  getter? finished

  def next_token : Token
    raise "finished" if @finished

    if @pos == 0
      raise "expected '$'" unless cur_char == '$'
      token = Token.new(:COMMAND_START, "$")
    else
      case cur_char
      when '['
        raise "Expected '$'" unless move_next == '$'
        token = Token.new(:COMMAND_START, "\[$")
      when ']'
        token = Token.new(:COMMAND_END, "\]")
      when '\0'
        token = Token.new(:COMMAND_END, "")
        @finished = true
      when ' '
        token = Token.new(:SEPERATOR, " ")
      when '"'
        move_next

        content = String.build do |str|
          until {'"', '\0'}.includes? cur_char
            str << read_unescaped

            move_next
          end
        end

        token = Token.new(:LITERAL, content)
      else
        content = String.build do |str|
          str << read_unescaped

          until {'[', ']', '$', '"', ' ', '\0'}.includes? peek_char
            move_next

            str << read_unescaped
          end
        end

        token = Token.new(:LITERAL, content)
      end
    end

    move_next

    token
  end

  private def read_unescaped
    if cur_char == '\\'
      # TODO: handle proper escapes?
      escape_char = move_next

      escape_char
    else
      cur_char
    end
  end

  private def cur_char
    return '\0' if @pos >= @str.size
    @str[@pos]
  end

  private def peek_char
    return '\0' if @pos + 1 >= @str.size
    @str[@pos + 1]
  end

  private def move_next
    @pos += 1
    cur_char
  end
end

record Literal,
  content : String

record Argument,
  contents : Array(Command | Literal)

record Command,
  name : Argument,
  args : Array(Argument)

class Parser
  @token : Token

  def initialize(@lexer : Lexer)
    @token = lexer.next_token
  end

  def parse : Command
    read_command
  end

  private def read_command
    raise "parser error" unless @token.type == :COMMAND_START

    next_token

    args = Array(Argument).new

    until @token.type == :COMMAND_END
      args << read_argument
      next_token unless @token.type == :COMMAND_END
    end

    command = args.shift
    Command.new(command, args)
  end

  private def read_argument
    raise "parser error" unless {:COMMAND_START, :LITERAL}.includes? @token.type

    contents = Array(Command | Literal).new

    until {:SEPERATOR, :COMMAND_END}.includes? @token.type
      case @token.type
      when :COMMAND_START
        contents << read_command
      when :LITERAL
        contents << read_literal
      end

      next_token
    end

    Argument.new(contents)
  end

  private def read_literal
    raise "parser error" unless @token.type == :LITERAL

    content = @token.content
    Literal.new(content)
  end

  private def next_token
    @token = @lexer.next_token
  end
end

COMMANDS = {
  "echo" => ->(args : Array(String)) { return args.join(" ") },
}

def evaluate_argument(argument)
  String.build do |str|
    argument.contents.each do |arg|
      case arg
      when Command
        str << execute_command(arg)
      when Literal
        str << arg.content
      end
    end
  end
end

def execute_command(command)
  name = evaluate_argument(command.name)
  args = command.args.map { |arg| evaluate_argument(arg) }

  COMMANDS[name].call(args)
end

str = <<-'COMMAND'
  $ec[$echo h]"o" [$e[$echo c]ho Hello]\ "world"!
  COMMAND

lexer = Lexer.new(str)
parser = Parser.new(lexer)
command = parser.parse
puts execute_command(command)
