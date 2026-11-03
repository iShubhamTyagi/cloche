# toppings.py

toppings.py: build the topping models once and render small icon sprites only.
- Eight toppings for the HUD bowls: berries, mint, chocolate shavings, gold flakes,
  sprinkles, sugar pearls, crushed pistachio, flower petals. Real size in mm.
- Output one 256 px transparent icon per topping (bowl-style heap) with a soft shadow, and
  keep the models in toppings.blend for toppings3d.py. Do not build the ganache section
  here and do not render placement sprites.
Budget: 5 MB for the icons.
