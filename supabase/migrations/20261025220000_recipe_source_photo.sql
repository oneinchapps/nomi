-- Rezepte, die von einem Foto (Kochbuch, Zeitschrift, handgeschriebene Karte) ausgelesen wurden.
alter type public.recipe_source add value if not exists 'photo';
