json.partial! "cards/card", card: @card

json.steps do
  json.array! @card.steps do |step|
    json.partial! "steps/step", step: step
  end
end
