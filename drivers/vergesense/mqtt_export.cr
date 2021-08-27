
require "./models"

class Vergesense::MqttExport < PlaceOS::Driver

  descriptive_name "Vergesense to MQTT Exporter"
  generic_name :VergesenseToMQTT
  description %(Export Vergesense people count data to an MQTT consumer)

  accessor vergesense : Vergesense_1
  accessor mqtt : GenericMQTT_1
  
  default_settings({
    mqtt_root_topic: "/t/root-topic/",
    floors_to_export: [
      "vergesense_building_id-floor_id"
    ],
    debug: false
  })

  @mqtt_root_topic : String = "/t/root-topic/"
  @floors_to_export : Array(String) = [] of String
  @debug : Bool = false
  
  @subscriptions : Int32 = 0
  @previous_vs_spaces = [] of Space

  def on_load
    on_update
  end

  def on_update
    @mqtt_root_topic  = setting(String, :mqtt_root_topic) || "/t/root-topic"
    @floors_to_export = setting(Array(String), :floors_to_export) || [] of String
    @debug = setting(Bool, :debug) || false

    subscriptions.clear
    @subscriptions = 0
    @floors_to_export.each do |floor|  
      system.subscribe(:Vergesense_1, floor) do |_subscription, vergesense_floor_json|
        vergesense_to_mqtt(Floor.from_json(vergesense_floor_json))
        @subscriptions += 1
      end
    end
  end

  def inspect_state
    {
      vergesense_subscriptions: @subscriptions
    }
  end

  private def vergesense_to_mqtt(vergesense_floor : Floor)
    changed_spaces = vergesense_floor.spaces - @previous_vs_spaces
    logger.debug { "#{changed_spaces.count}/#{vergesense_floor.spaces.count} spaces have changed" } if @debug
    changed_spaces.each do |s|
      topic = [ @mqtt_root_topic, s.building_ref_id, "-", s.floor_ref_id, ".", s.space_type, ".", s.space_ref_id, ".", "count" ].join
      payload = s.people ? (s.people.not_nil!.count || 0) : 0  # There must be a neater way to do this
      mqtt.publish(topic, payload.to_s)
      logger.debug { "Published #{payload} to #{topic}" } if @debug
    end
    @previous_vs_spaces = vergesense_floor.spaces
  end
end
