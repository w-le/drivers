module MuleSoft; end

require "./models"
require "place_calendar"

class MuleSoft::CalendarExporter < PlaceOS::Driver
  descriptive_name "MuleSoft Bookings to Calendar Events Exporter"
  generic_name :Bookings
  description %(Retrieves and creates bookings using the MuleSoft API)

  default_settings({
    time_zone:          "Australia/Sydney"
  })


  accessor calendar : Calendar_1


  @time_zone : Time::Location = Time::Location.load("Australia/Sydney")
  @bookings : Array(Booking) = [] of Booking
  @events   : Array(PlaceCalendar::Event)   = [] of PlaceCalendar::Event
  
  # An array of Attendee that has only the system (room) email address. Generally static
  @just_this_system : Array(PlaceCalendar::Event::Attendee) = {
    "name":  system.display_name || system.name,
    "email": system.email.not_nil!
  }

  def on_load
    on_update
  end

  def on_update
    subscriptions.clear
    subscription = system.subscribe(:Bookings_1, :bookings) do |subscription, mulesoft_bookings|
      # values are always raw JSON strings
      @bookings = Array(Booking).from_json(mulesoft_bookings)
      @bookings.each { |b| export_booking(b) }
    end
  end

  def status()
    "WIP"
  end

  protected def export_booking(booking : Booking)
    event = booking.to_placeos
    
    existing_events_json = calendar.list_events(
      calendar_id:  system.email.not_nil!,
      period_start: event.event_start,
      period_end:   event.event_end
    )
    existing_events = Array(Event).from_json(existing_events_json)

    calendar.create_event(
      title:        event.title,
      event_start:  event.event_start,
      event_end:    event.event_end,
      description:  event.body,
      user_id:      system.email.not_nil!,
      attendees:    @just_this_system
    ) unless event_already_exists?(event, existing_events)
  end

  protected def event_already_exists?(new_event : PlaceCalendar::Event, existing_events : Array(PlaceCalendar::Event))
    existing_events.each do |existing_event|
      return true if events_match?(new_event, existing_event)
    end
    false
  end

  protected def events_match?(event_a : PlaceCalendar::Event, event_b : PlaceCalendar::Event)
    event_a.title       == event_b.title && 
    event_a.event_start == event_b.event_start &&
    event_a.event_end   == event_b.event_end
  end

end