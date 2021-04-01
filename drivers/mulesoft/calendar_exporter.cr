module MuleSoft; end

require "./models"
require "place_calendar"

class MuleSoft::CalendarExporter < PlaceOS::Driver
  descriptive_name "MuleSoft Bookings to Calendar Events Exporter"
  generic_name :Bookings
  description %(Retrieves and creates bookings using the MuleSoft API)

  default_settings({
    calendar_time_zone: "Australia/Sydney"
  })

  accessor calendar : Calendar_1

  @time_zone : Time::Location = Time::Location.load("Australia/Sydney")
  @bookings : Array(Booking) = [] of Booking
  @existing_events : Array(JSON::Any) = [] of JSON::Any
  # An array of Attendee that has only the system (room) email address. Generally static
  @just_this_system : NamedTuple(email: String, name: String) = {email: "", name: ""}
  
  def on_load  
    @just_this_system = {
      "email": system.email.not_nil!,
      "name":  system.name
    }
    on_update
  end

  def on_update
    subscriptions.clear
    

    time_zone = setting?(String, :calendar_time_zone).presence
    @time_zone = Time::Location.load(time_zone) if time_zone
    self[:timezone] = Time.local.to_s

    subscription = system.subscribe(:Bookings_1, :bookings) do |subscription, mulesoft_bookings|
      logger.debug {"DETECTED changed in Mulesoft Bookings.."}
      # values are always raw JSON strings
      @bookings = Array(Booking).from_json(mulesoft_bookings)
      logger.debug {"#{@bookings.size} bookings in total"}
      update_events
    end
  end

  def status()
    @bookings
  end

  def update_events
    now = Time.local @time_zone
    from = now - 7.days
    til  = now + 7.days

    logger.debug {"FETCHING existing Calendar events..."}

    @existing_events = calendar.list_events(
      calendar_id:  system.email.not_nil!,
      period_start: from.to_unix,
      period_end:   til.to_unix
    ).get.as_a
    
    logger.debug {"#{@existing_events.size} events in total"}

    @bookings.each {|b| export_booking(b)}
  end

  protected def export_booking(booking : Booking)
    logger.debug {"Checking for existing bookings: #{booking}"}
    event = booking.to_placeos

    # unless event_already_exists?(event, @existing_events)
      logger.debug {"EXPORTING booking #{event["body"]} starting at #{Time.unix(event["event_start"].not_nil!.to_i).to_local}"}
      calendar.create_event(
        title:        event["title"] || event["body"],
        event_start:  event["event_start"],
        event_end:    event["event_end"],
        description:  event["body"],
        user_id:      system.email.not_nil!,
        attendees:    [@just_this_system]
      )
    # end
  end

  protected def event_already_exists?(new_event : Hash(String, Int64 | String | Nil), @existing_events : Array(JSON::Any))
    @existing_events.each do |existing_event|
      return true if events_match?(new_event, existing_event.as_h)
    end
    false
  end

  protected def events_match?(event_a : Hash(String, Int64 | String | Nil), event_b : Hash(String, JSON::Any))
    event_a.select("title", "event_start", "event_end") == event_b.select("title", "event_start", "event_end")
  end

end