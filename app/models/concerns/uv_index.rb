# Maps a UV index value to its WHO exposure-category label.
#
# https://www.who.int/news-room/questions-and-answers/item/radiation-the-ultraviolet-(uv)-index
module UvIndex
  UNKNOWN_LABEL = "Unknown"

  def self.label_for(value)
    return UNKNOWN_LABEL if value.nil?

    case value.to_f
    when 0...3 then "Low"
    when 3...6 then "Moderate"
    when 6...8 then "High"
    when 8...11 then "Very high"
    else "Extreme"
    end
  end
end
