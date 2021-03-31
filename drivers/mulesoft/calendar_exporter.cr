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

    subscription = system.subscribe(:Bookings_1, :bookings) do |subscription, mulesoft_bookings|
      # values are always raw JSON strings
      @bookings = Array(Booking).from_json(mulesoft_bookings)
      update_events
    end
  end

  def status()
    "WIP"
  end

  protected def update_events
    now = Time.local @time_zone
    from = now - 7.days
    til  = now + 7.days

    @existing_events = calendar.list_events(
      calendar_id:  system.email.not_nil!,
      period_start: from.to_unix,
      period_end:   til.to_unix
    ).get.as_a

    @bookings.each {|b| export_booking(b)}
  end

  protected def export_booking(booking : Booking)
    event = booking.to_placeos

    calendar.create_event(
      title:        event["title"] || event["body"],
      event_start:  event["event_start"],
      event_end:    event["event_end"],
      description:  event["body"],
      user_id:      system.email.not_nil!,
      attendees:    [@just_this_system]
    ) unless event_already_exists?(event, @existing_events)
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