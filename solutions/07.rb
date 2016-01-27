module LazyMode
  include Enumerable

  def self.create_file(name, &block)
    new_file = File.new(name)
    new_file.instance_eval(&block)
    new_file
  end

  class Date
    attr_reader :year, :month, :day

    DAY_TYPE = { :d => 1, :w => 7, :m => 30 }

    def initialize(date)
      @year = date.slice(0, 4)
      @month = date.slice(5, 2)
      @day = date.slice(8, 2)
    end

    def to_s
      "#{year}-#{month}-#{day}"
    end

    def add(time_frame)
      time = (/\+\d+[dwm]/.match time_frame).to_s
      count = (/\d+/.match time).to_s.to_i
      type = (/[dwm]/.match time).to_s.to_sym
      days = DAY_TYPE[type] * count
      time_travel(self, days)
    end

    def ==(other)
      self.to_s == other.to_s ? true : false
    end

    def >=(other)
      return false if year.to_i < other.year.to_i
      return false if month.to_i < other.month.to_i
      return false if day.to_i < other.day.to_i
      true
    end

    def <=(other)
      return false if year.to_i > other.year.to_i
      return false if month.to_i > other.month.to_i
      return false if day.to_i > other.day.to_i
      true
    end

    private

    def time_travel(date, days)
      nights, months, years = date.day.to_i + days, date.month.to_i, date.year
      while nights > 30 do
        months, nights = months.to_i + 1, nights.to_i - 30
      end
      while months > 12 do
        years, months = years.to_i + 1, months.to_i - 12
      end
      LazyMode::Date.new(format_date(years.to_s, months.to_s, nights.to_s))
    end

    def format_date(years, months, nights)
      formatted_year = ("0" * (4 - years.length)) + years
      formatted_month = months.length == 1 ? "0" + months : months
      formatted_day = nights.length == 1 ? "0" + nights : nights
      "#{formatted_year}-#{formatted_month}-#{formatted_day}"
    end
  end

  class File
    attr_reader :name, :notes

    def initialize(name)
      @name = name
      @notes = []
    end

    def note(header, *tags, &block)
      new_note = Note.new(header, @name, *tags)
      new_note.instance_eval(&block)
      @notes << new_note
    end

    def daily_agenda(day)
      agenda = []
      tasks = collect_tasks(@notes)
      tasks.each { |note| agenda << return_note(note, day, day)  }
      agenda.delete(nil)
      new_agenda = Agenda.new(agenda)
    end

    def weekly_agenda(day)
      agenda = []
      tasks = collect_tasks(@notes)
      tasks.each { |note| agenda << return_note(note, day, day.add("+6d")) }
      agenda.delete(nil)
      new_agenda = Agenda.new(agenda)
    end

    private

    def collect_tasks(tasks)
      collection = []
      tasks.each { |task| collection << task }
      tasks.each { |task| collection << task.sub_notes}
      collection.flatten
    end

    def return_note(note, start_date, end_date)
      (note.date >= start_date and note.date <= end_date) ? note : nil
    end
  end

  class Note
    attr_reader :tags, :header, :file_name, :sub_notes, :date, :recurrence

    def initialize(header, file_name, *tags)
      @header = header
      @tags = tags
      @status = :topostpone
      @file_name = file_name
      @body = ''
      @sub_notes = []
    end

    def note(header, *tags, &block)
      new_note = Note.new(header, @file_name, *tags)
      new_note.instance_eval(&block)
      @sub_notes << new_note
    end

    def body(*text)
      text.size == 1 ? @body = text.first : @body
    end

    def status(*arguments)
      arguments.size == 1 ? @status = arguments.first : @status
    end

    def scheduled(date)
      @recurrence = (/\+\d+[dwm]/.match date).to_s
      @date = LazyMode::Date.new(date)
    end
  end

  class Agenda
    attr_reader :notes

    def initialize(agenda)
      @notes = agenda
    end

    def where(tag: /./, text: /./, status: /./)
      filtered_notes = []
      @notes.each { |note| filtered_notes << tag_finder(note, tag) }
      @notes.each { |note| remove_text(filtered_notes, note, text) }
      @notes.each { |note| remove_status(filtered_notes, note, status) }
      filtered_notes.delete(nil)
      filtered_agenda = Agenda.new(filtered_notes)
    end

    private

    def remove_text(tasks, note, text)
      if (text.match note.header).nil? and (text.match note.body).nil?
        tasks.delete(note)
      end
    end

    def remove_status(tasks, note, status)
      tasks.delete(note) if (note.status.to_s.match(status.to_s)).nil?
    end

    def tag_finder(note, tag)
      note.tags.include?(tag) ? note : nil
    end
  end
end
