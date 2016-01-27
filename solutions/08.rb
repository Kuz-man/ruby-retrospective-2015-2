module Excel
  NUMBER = /\A[0-9]+\z/
  CELL = "[A-Z]+[0-9]+"
  ROWS = ("A"..."ZZZ").to_a
  OPERATIONS = {
    :ADD => "+",
    :SUBTRACT => "-",
    :MULTIPLY => "*",
#    :DIVIDE => "/",
    :MOD => "%"
  } # беше със символи, но Skeptic реве, че няма шпация след *
  PARENTHESIS = /\((\w|\W)+\)/

  def delete_empty_cells(spreadsheet)
    spreadsheet.select { |cell| cell.value != ""}
  end

  def get_cell(cell_index)
    data.find { |cell| cell.cell_id == cell_index }
  end

  def return_parameters(cell_index)
    cell_at(cell_index).match(PARENTHESIS).to_s[1..-2].split(",").map do |item|
      item.strip
    end
  end

  def is_equation?(value)
    value.start_with?("=")
  end

  def return_cell(cell_index)
    self[cell_at(cell_index).match(/#{CELL}\z/).to_s]
  end

  def return_number(cell_index)
    cell_at(cell_index).match(/[0-9]+/).to_s
  end

  def cell_array(result, array, column)
    array.strip.split(/\t|  /).each_with_index do |value, row|
      result << Cell.new(value, column + 1, ROWS[row])
    end
  end
end

class Spreadsheet
  include Excel
  attr_reader :data

  def initialize(tabbed_values = "")
    @data = create_cells(tabbed_values)
  end

  def empty?
    data.empty?
  end

  def cell_at(cell_index)
    exception_thrower(cell_index)
    get_cell(cell_index).value
  end

  def [](cell_index)
    return cell_index if cell_index.match(NUMBER)
    exception_thrower(cell_index)
    return cell_at(cell_index) if ! cell_at(cell_index).start_with?("=")
    return return_number(cell_index) if get_cell(cell_index).equals_number?
    return return_cell(cell_index) if get_cell(cell_index).equals_cell?
    calculate(get_cell(cell_index).operation, return_parameters(cell_index))
  end

  def to_s #някакъв map може би ще е по-смислен
    result = self[data.first.cell_id].to_s
    data.each_cons(2) do |first_cell, second_cell|
      if first_cell.column == second_cell.column
        result += "\t" + self[second_cell.cell_id].to_s
      else
        result += "\n" + self[second_cell.cell_id].to_s
      end
    end
    result
  end

  private

  def create_cells(tabbed_values)
    result = []
    tabbed_values.strip.split(/\n/).each_slice(1).with_index do |item, column|
      cell_array(result, item[0], column)
    end #da razkaram slice?
    delete_empty_cells(result)
  end

  def calculate(operation, parameters)
    if operation.to_s == "DIVIDE" # Skeptic again :)
      result = self[parameters[0]].to_f / self[parameters[1]].to_f
    else
      result = (parameters.map do |item|
        self[item].to_f
      end.reduce(OPERATIONS[operation].to_sym))
    end
    result.to_i == result ? result.to_i.to_s : result.to_f.round(2).to_s
  end

  def exception_thrower(cell_index)
    if ! cell_index.match(/\A#{CELL}\z/)
      raise Error.new("Invalid cell index \'#{cell_index}\'")
    elsif get_cell(cell_index) == nil
      raise Error.new("Cell \'#{cell_index}\' does not exist")
    end
  end
end

class Spreadsheet::Error < StandardError
end

class Cell
  attr_reader :value, :column, :row, :operation
  include Excel

  def initialize(value, column, row)
    @value = value
    @column = column
    @row = row
    @operation = check_operation
  end

  def cell_id
    row + column.to_s
  end

  def equals_cell?
    value.match(/\A=#{CELL}\z/) != nil
  end

  def equals_number?
    value.match(/\A=[0-9]+\z/) != nil
  end

  private

  def check_operation
    is_equation?(value) ? value[1..-1].match(/\w+/).to_s.to_sym : nil
  end
end
