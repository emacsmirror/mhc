require 'forwardable'

module Mhc
  class Occurrence
    include Comparable
    extend Forwardable

    def_delegators :@event,
    :path,
    :alarm,
    :categories,
    :description,
    :body,
    :location,
    :priority,
    :record_id,
    :uid,
    :subject,
    :recurrence_tag,
    :mission_tag,
    :allday?,
    :holiday?

    attr_reader :event

    def initialize(event, date_range)
      @event = event

      if date_range.respond_to?(:first)
        @start_date = date_range.first
        @end_date   = date_range.last
      else
        @start_date = date_range
        @end_date   = date_range
      end
    end

    def date
      if @start_date.respond_to?(:hour)
        Mhc::PropertyValue::Date.new(@start_date.year, @start_date.month, @start_date.day)
      else
        @start_date
      end
    end

    # FIXME: TimeRange class should be implemented
    def time_range
      range = Mhc::PropertyValue::Range.new(Mhc::PropertyValue::Time)
      if dtstart.respond_to?(:hour)
        range.parse("#{dtstart.hour}:#{dtstart.min}-#{dtend.hour}:#{dtend.min}")
      else
        return range # allday
      end
    end

    def dtstart
      if allday?
        @start_date
      else
        if @start_date.respond_to?(:hour)
          @start_date
        else
          # if range is open, use end time as start time
          @event.time_range.first&.to_datetime(@start_date) || dtend
        end
      end
    end

    def dtend
      if allday?
        @end_date + 1
      else
        if @end_date.respond_to?(:hour)
          @end_date
        else
          # if range is open, use start time as end time
          @event.time_range.last&.to_datetime(@end_date) || dtstart
        end
      end
    end

    def first
      @start_date
    end

    def last
      @end_date
    end

    def days
      @end_date - @start_date + 1
    end

    def oneday?
      @start_date == @end_date
    end

    def to_mhc_string
      if allday?
        return "#{dtstart.to_mhc_string}" if oneday?
        return "#{@start_date.to_mhc_string}-#{@end_date.to_mhc_string}"
      else
        time = dtstart.strftime("%Y%m%d %H:%m-") + ((@start_date.to_date == @end_date.to_date) ? dtend.strftime("%H:%m") : dtend.strftime("%Y%m%dT%H:%m"))
        return time + " " + subject.to_mhc_string
      end
    end

    alias_method :to_s, :to_mhc_string

    def <=>(o)
      if o.respond_to?(:dtstart)
        return self.dtstart <=> o.dtstart
      else
        return self.dtstart <=> o
      end
    end

  end # class Occurrence
end # module Mhc
