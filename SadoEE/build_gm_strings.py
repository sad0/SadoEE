"""Camp merchant UI strings per language -> tra/<language>/M_PSXGT.lua (PSXGM_Strings, read by M_PSXGM.lua).

    python build_gm_strings.py

English is M_PSXGM.lua's own table (G.EN); a language only lists what it translates (a missing key falls back to
English). The installer (component #8) copies the chosen language's file to override/M_PSXGT.lua.
Category names follow each game's own words where it has them (item types, proficiencies).
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))

KEYS = ['gm_title', 'gm_all', 'gm_weapons', 'gm_armor', 'gm_equipment', 'gm_potions', 'gm_scrolls', 'gm_gems',
        'gm_ammo', 'gm_misc', 'gm_bows', 'gm_crossbows', 'gm_slings', 'gm_daggers', 'gm_short_swords',
        'gm_long_swords', 'gm_bastard_swords', 'gm_two_handed', 'gm_katanas', 'gm_scimitars', 'gm_axes', 'gm_maces',
        'gm_hammers', 'gm_flails', 'gm_clubs', 'gm_staves', 'gm_spears', 'gm_halberds', 'gm_fists', 'gm_robes',
        'gm_leather', 'gm_mail', 'gm_plate', 'gm_other_armor', 'gm_shields', 'gm_helmets', 'gm_bracers', 'gm_rings',
        'gm_amulets', 'gm_belts', 'gm_boots', 'gm_cloaks', 'gm_wands', 'gm_bags', 'gm_arrows', 'gm_bolts',
        'gm_bullets', 'gm_darts', 'gm_search', 'gm_usable', 'gm_affordable', 'gm_sort', 'gm_sort_auto', 'gm_sort_type',
        'gm_sort_price', 'gm_sort_name', 'gm_buy', 'gm_done', 'gm_vanilla', 'gm_back', 'gm_price', 'gm_unlimited',
        'gm_stock', 'gm_from', 'gm_wished', 'gm_items', 'gm_empty', 'gm_no_gold', 'gm_full', 'gm_cannot_buy',
        'gm_bought', 'gm_select', 'gm_total', 'gm_skin', 'gm_skin_1', 'gm_skin_2', 'gm_sell_marked', 'gm_sell_none',
        'gm_sold']

T = {
    'french': [
        'Grand marchand', 'Tout', 'Armes', 'Armures', 'Équipement', 'Potions', 'Parchemins', 'Gemmes', 'Munitions',
        'Divers', 'Arcs', 'Arbalètes', 'Frondes', 'Dagues', 'Épées courtes', 'Épées longues', 'Épées bâtardes',
        'Épées à deux mains', 'Katanas', 'Cimeterres', 'Haches', 'Masses', 'Marteaux de guerre',
        'Fléaux, morgensterns', 'Gourdins', 'Bâtons', 'Lances', 'Hallebardes', 'Armes de poing', 'Robes', 'Cuir',
        'Mailles', 'Plates', 'Autres armures', 'Boucliers', 'Casques', 'Bracelets, gantelets', 'Anneaux', 'Amulettes',
        'Ceintures', 'Bottes', 'Capes', 'Baguettes', 'Sacs', 'Flèches', 'Carreaux', 'Billes', 'Dards', 'Rechercher',
        'Utilisable', 'Abordable', 'Tri : %s', 'Auto', 'Type', 'Prix', 'Nom', 'Acheter', 'Terminer',
        'Vendre / vue normale', 'Grand marchand', '%d po', 'Illimité', '%d en stock', 'Vient de : %s', 'Souhaits',
        '%d objets', 'Rien pour le moment : visitez des boutiques pour remplir le grand marchand.',
        "Pas assez d'or", 'Sac plein : choisissez un autre personnage', "Impossible d'acheter ça maintenant",
        'Acheté : %s x%d', 'Clic : choisir. Ctrl + clic : souhait. Clic droit : description.', 'Total : %d po',
        'Tableau : %s', 'avis épinglés', 'peint', 'Vendre marqués : %s po', 'Rien de marqué',
        'Vendu depuis le coffre : %d po'],
    'german': [
        'Lagerhändler', 'Alles', 'Waffen', 'Rüstungen', 'Ausrüstung', 'Tränke', 'Schriftrollen', 'Edelsteine',
        'Munition', 'Verschiedenes', 'Bögen', 'Armbrüste', 'Schleudern', 'Dolche', 'Kurzschwerter', 'Langschwerter',
        'Bastardschwerter', 'Zweihänder', 'Katanas', 'Krummsäbel', 'Äxte', 'Streitkolben', 'Kriegshämmer',
        'Flegel, Morgensterne', 'Keulen', 'Kampfstäbe', 'Speere', 'Hellebarden', 'Faustwaffen', 'Roben', 'Leder',
        'Kettenpanzer', 'Plattenpanzer', 'Andere Rüstungen', 'Schilde', 'Helme', 'Armschienen, Panzerhandschuhe',
        'Ringe', 'Amulette', 'Gürtel', 'Stiefel', 'Umhänge', 'Zauberstäbe', 'Beutel', 'Pfeile', 'Bolzen', 'Kugeln',
        'Wurfpfeile', 'Suchen', 'Benutzbar', 'Bezahlbar', 'Sortierung: %s', 'Auto', 'Typ', 'Preis', 'Name', 'Kaufen',
        'Fertig', 'Verkaufen / normale Ansicht', 'Lagerhändler', '%d GM', 'Unbegrenzt', '%d auf Lager', 'Von: %s',
        'Wunschliste', '%d Gegenstände', 'Noch nichts: besucht Läden, um den Lagerhändler zu füllen.',
        'Nicht genug Gold', 'Rucksack voll: wählt einen anderen Charakter', 'Kann das jetzt nicht kaufen',
        'Gekauft: %s x%d', 'Klick: wählen. Strg + Klick: Wunschliste. Rechtsklick: Beschreibung.', 'Gesamt: %d GM',
        'Brett: %s', 'angeheftete Zettel', 'gemalt', 'Markierte verkaufen: %s GM', 'Nichts markiert',
        'Aus dem Lager verkauft: %d GM'],
    'spanish': [
        'Gran mercader', 'Todo', 'Armas', 'Armaduras', 'Equipo', 'Pociones', 'Pergaminos', 'Gemas', 'Munición',
        'Varios', 'Arcos', 'Ballestas', 'Hondas', 'Dagas', 'Espadas cortas', 'Espadas largas', 'Espadas bastardas',
        'Mandobles', 'Katanas', 'Cimitarras', 'Hachas', 'Mazas', 'Martillos de guerra', 'Manguales, lucero del alba',
        'Garrotes', 'Bastones', 'Lanzas', 'Alabardas', 'Armas de puño', 'Túnicas', 'Cuero', 'Mallas', 'Placas',
        'Otras armaduras', 'Escudos', 'Yelmos', 'Brazales, guanteletes', 'Anillos', 'Amuletos', 'Cinturones', 'Botas',
        'Capas', 'Varitas', 'Bolsas', 'Flechas', 'Virotes', 'Balas', 'Dardos', 'Buscar', 'Utilizable', 'Asequible',
        'Orden: %s', 'Auto', 'Tipo', 'Precio', 'Nombre', 'Comprar', 'Hecho', 'Vender / vista normal', 'Gran mercader',
        '%d po', 'Ilimitado', '%d en existencia', 'De: %s', 'Deseos', '%d objetos',
        'Nada todavía: visita tiendas para llenar el gran mercader.', 'Oro insuficiente',
        'Mochila llena: elige otro personaje', 'No se puede comprar ahora', 'Comprado: %s x%d',
        'Clic: elegir. Ctrl + clic: deseos. Clic derecho: descripción.', 'Total: %d po', 'Tablón: %s',
        'avisos clavados', 'pintado', 'Vender marcados: %s po', 'Nada marcado', 'Vendido del alijo: %d po'],
    'italian': [
        'Gran mercante', 'Tutto', 'Armi', 'Armature', 'Equipaggiamento', 'Pozioni', 'Pergamene', 'Gemme',
        'Munizioni', 'Varie', 'Archi', 'Balestre', 'Fionde', 'Pugnali', 'Spade corte', 'Spade lunghe',
        'Spade bastarde', 'Spadoni', 'Katana', 'Scimitarre', 'Asce', 'Mazze', 'Martelli da guerra',
        'Flagelli, morning star', 'Randelli', 'Bastoni', 'Lance', 'Alabarde', 'Armi da pugno', 'Tuniche', 'Cuoio',
        'Maglia', 'Piastre', 'Altre armature', 'Scudi', 'Elmi', 'Bracciali, guanti', 'Anelli', 'Amuleti', 'Cinture',
        'Stivali', 'Mantelli', 'Bacchette', 'Sacche', 'Frecce', 'Quadrelli', 'Proiettili', 'Dardi', 'Cerca', 'Usabile',
        'Acquistabile', 'Ordine: %s', 'Auto', 'Tipo', 'Prezzo', 'Nome', 'Compra', 'Fatto', 'Vendi / vista normale',
        'Gran mercante', '%d mo', 'Illimitato', '%d disponibili', 'Da: %s', 'Desideri', '%d oggetti',
        'Ancora niente: visita i negozi per riempire il gran mercante.', 'Oro insufficiente',
        'Zaino pieno: scegli un altro personaggio', 'Impossibile comprarlo ora', 'Comprato: %s x%d',
        'Clic: scegli. Ctrl + clic: desideri. Clic destro: descrizione.', 'Totale: %d mo', 'Bacheca: %s',
        'avvisi appesi', 'dipinta', 'Vendi segnati: %s mo', 'Niente segnato', 'Venduto dalla scorta: %d mo'],
    'polish': [
        'Wielki kupiec', 'Wszystko', 'Broń', 'Pancerze', 'Wyposażenie', 'Mikstury', 'Zwoje', 'Klejnoty', 'Amunicja',
        'Różne', 'Łuki', 'Kusze', 'Proce', 'Sztylety', 'Krótkie miecze', 'Długie miecze', 'Miecze półtoraręczne',
        'Miecze dwuręczne', 'Katany', 'Sejmitary', 'Topory', 'Buzdygany', 'Młoty bojowe', 'Cepy, morgensterny',
        'Pałki', 'Kostury', 'Włócznie', 'Halabardy', 'Broń pięściowa', 'Szaty', 'Skórzane', 'Kolcze', 'Płytowe',
        'Inne pancerze', 'Tarcze', 'Hełmy', 'Karwasze, rękawice', 'Pierścienie', 'Amulety', 'Pasy', 'Buty',
        'Płaszcze', 'Różdżki', 'Torby', 'Strzały', 'Bełty', 'Pociski', 'Strzałki', 'Szukaj', 'Do użycia',
        'Na kieszeń', 'Sortuj: %s', 'Auto', 'Typ', 'Cena', 'Nazwa', 'Kup', 'Gotowe', 'Sprzedaj / zwykły widok',
        'Wielki kupiec', '%d szt. zł.', 'Bez limitu', '%d w zapasie', 'Od: %s', 'Życzenia', '%d przedmiotów',
        'Jeszcze nic: odwiedź sklepy, aby zapełnić wielkiego kupca.', 'Za mało złota',
        'Plecak pełny: wybierz inną postać', 'Teraz nie można tego kupić', 'Kupiono: %s x%d',
        'Klik: wybierz. Ctrl + klik: życzenia. Prawy klik: opis.', 'Razem: %d szt. zł.', 'Tablica: %s',
        'przypięte ogłoszenia', 'malowana', 'Sprzedaj oznaczone: %s szt. zł.', 'Nic nie oznaczono',
        'Sprzedano ze skrytki: %d szt. zł.'],
    'russian': [
        'Великий торговец', 'Все', 'Оружие', 'Доспехи', 'Снаряжение', 'Зелья', 'Свитки', 'Самоцветы', 'Боеприпасы',
        'Разное', 'Луки', 'Арбалеты', 'Пращи', 'Кинжалы', 'Короткие мечи', 'Длинные мечи', 'Полуторные мечи',
        'Двуручные мечи', 'Катаны', 'Ятаганы', 'Топоры', 'Булавы', 'Боевые молоты', 'Цепы, моргенштерны', 'Дубины',
        'Посохи', 'Копья', 'Алебарды', 'Кулачное оружие', 'Мантии', 'Кожаные', 'Кольчужные', 'Латные',
        'Другие доспехи', 'Щиты', 'Шлемы', 'Наручи, рукавицы', 'Кольца', 'Амулеты', 'Пояса', 'Сапоги', 'Плащи',
        'Жезлы', 'Сумки', 'Стрелы', 'Болты', 'Пули', 'Дротики', 'Поиск', 'Можно носить', 'По карману',
        'Сортировка: %s', 'Авто', 'Тип', 'Цена', 'Имя', 'Купить', 'Готово', 'Продать / обычный вид',
        'Великий торговец', '%d зм', 'Без ограничений', '%d в наличии', 'От: %s', 'Желаемое', 'Предметов: %d',
        'Пока пусто: посетите лавки, чтобы пополнить товар.', 'Не хватает золота',
        'Рюкзак полон: выберите другого героя', 'Сейчас это не купить', 'Куплено: %s x%d',
        'Клик: выбрать. Ctrl + клик: желаемое. Правый клик: описание.', 'Итого: %d зм', 'Доска: %s',
        'приколотые объявления', 'рисованная', 'Продать отмеченное: %s зм', 'Ничего не отмечено',
        'Продано из тайника: %d зм'],
    'portuguese': [
        'Grande mercador', 'Tudo', 'Armas', 'Armaduras', 'Equipamento', 'Poções', 'Pergaminhos', 'Gemas', 'Munição',
        'Diversos', 'Arcos', 'Bestas', 'Fundas', 'Adagas', 'Espadas curtas', 'Espadas longas', 'Espadas bastardas',
        'Montantes', 'Katanas', 'Cimitarras', 'Machados', 'Maças', 'Martelos de guerra', 'Manguais, maças-estrela',
        'Clavas', 'Cajados', 'Lanças', 'Alabardas', 'Armas de punho', 'Túnicas', 'Couro', 'Malha', 'Placas',
        'Outras armaduras', 'Escudos', 'Elmos', 'Braçadeiras, manoplas', 'Anéis', 'Amuletos', 'Cintos', 'Botas',
        'Mantos', 'Varinhas', 'Bolsas', 'Flechas', 'Virotes', 'Balas', 'Dardos', 'Buscar', 'Utilizável', 'Acessível',
        'Ordem: %s', 'Auto', 'Tipo', 'Preço', 'Nome', 'Comprar', 'Concluir', 'Vender / visão normal',
        'Grande mercador', '%d po', 'Ilimitado', '%d em estoque', 'De: %s', 'Desejos', '%d itens',
        'Nada ainda: visite lojas para abastecer o grande mercador.', 'Ouro insuficiente',
        'Mochila cheia: escolha outro personagem', 'Não é possível comprar agora', 'Comprado: %s x%d',
        'Clique: escolher. Ctrl + clique: desejos. Botão direito: descrição.', 'Total: %d po', 'Quadro: %s',
        'avisos pregados', 'pintado', 'Vender marcados: %s po', 'Nada marcado', 'Vendido do baú: %d po'],
    'czech': [
        'Velký kupec', 'Vše', 'Zbraně', 'Zbroje', 'Výbava', 'Lektvary', 'Svitky', 'Drahokamy', 'Střelivo', 'Různé',
        'Luky', 'Kuše', 'Praky', 'Dýky', 'Krátké meče', 'Dlouhé meče', 'Bastardy', 'Obouruční meče', 'Katany',
        'Šavle', 'Sekery', 'Palcáty', 'Válečná kladiva', 'Cepy, řemdihy', 'Kyje', 'Hole', 'Kopí', 'Halapartny',
        'Pěstní zbraně', 'Róby', 'Kožené', 'Kroužkové', 'Plátové', 'Jiné zbroje', 'Štíty', 'Přilby',
        'Náramky, rukavice', 'Prsteny', 'Amulety', 'Opasky', 'Boty', 'Pláště', 'Hůlky', 'Vaky', 'Šípy', 'Šipky',
        'Kuličky', 'Vrhací šipky', 'Hledat', 'Použitelné', 'Dostupné', 'Řazení: %s', 'Auto', 'Typ', 'Cena', 'Název',
        'Koupit', 'Hotovo', 'Prodat / běžný pohled', 'Velký kupec', '%d zl', 'Neomezeně', '%d na skladě', 'Od: %s',
        'Přání', '%d předmětů', 'Zatím nic: navštivte obchody, aby se kupec zaplnil.', 'Málo zlata',
        'Batoh plný: vyberte jinou postavu', 'Teď to koupit nelze', 'Koupeno: %s x%d',
        'Klik: vybrat. Ctrl + klik: přání. Pravý klik: popis.', 'Celkem: %d zl', 'Nástěnka: %s',
        'připíchnuté vývěsky', 'malovaná', 'Prodat označené: %s zl', 'Nic označeno', 'Prodáno ze skrýše: %d zl'],
    'hungarian': [
        'Nagykereskedő', 'Mind', 'Fegyverek', 'Páncélok', 'Felszerelés', 'Italok', 'Tekercsek', 'Drágakövek',
        'Lőszer', 'Egyéb', 'Íjak', 'Számszeríjak', 'Parittyák', 'Tőrök', 'Rövid kardok', 'Hosszú kardok',
        'Fattyúkardok', 'Kétkezes kardok', 'Katanák', 'Szablyák', 'Fejszék', 'Buzogányok', 'Harci kalapácsok',
        'Cséphadarók, hajnalcsillagok', 'Bunkók', 'Botok', 'Lándzsák', 'Alabárdok', 'Ökölfegyverek', 'Köpenyek',
        'Bőr', 'Láncing', 'Lemez', 'Egyéb páncélok', 'Pajzsok', 'Sisakok', 'Karvédők, kesztyűk', 'Gyűrűk', 'Amulettek',
        'Övek', 'Csizmák', 'Köpönyegek', 'Pálcák', 'Zsákok', 'Nyílvesszők', 'Számszeríjvesszők', 'Golyók',
        'Dobónyilak', 'Keresés', 'Használható', 'Megfizethető', 'Rendezés: %s', 'Auto', 'Típus', 'Ár', 'Név', 'Vétel',
        'Kész', 'Eladás / normál nézet', 'Nagykereskedő', '%d at', 'Korlátlan', '%d raktáron', 'Innen: %s', 'Kívánság',
        '%d tárgy', 'Még semmi: látogass boltokat, hogy feltöltsd a kereskedőt.', 'Nincs elég arany',
        'Tele a hátizsák: válassz másik karaktert', 'Most nem vehető meg', 'Megvéve: %s x%d',
        'Kattintás: kiválaszt. Ctrl + kattintás: kívánság. Jobb klikk: leírás.', 'Összesen: %d at', 'Tábla: %s',
        'kitűzött hirdetmények', 'festett', 'Megjelöltek eladása: %s at', 'Nincs megjelölve',
        'Eladva a raktárból: %d at'],
    'turkish': [
        'Büyük tüccar', 'Tümü', 'Silahlar', 'Zırhlar', 'Teçhizat', 'İksirler', 'Parşömenler', 'Mücevherler',
        'Mühimmat', 'Çeşitli', 'Yaylar', 'Arbaletler', 'Sapanlar', 'Hançerler', 'Kısa kılıçlar', 'Uzun kılıçlar',
        'Piç kılıçlar', 'İki elli kılıçlar', 'Katanalar', 'Palalar', 'Baltalar', 'Gürzler', 'Savaş çekiçleri',
        'Döğenler, sabahyıldızları', 'Sopalar', 'Asalar', 'Mızraklar', 'Teberler', 'Yumruk silahları', 'Cüppeler',
        'Deri', 'Zincir', 'Plaka', 'Diğer zırhlar', 'Kalkanlar', 'Miğferler', 'Bileklikler, eldivenler', 'Yüzükler',
        'Muskalar', 'Kemerler', 'Çizmeler', 'Pelerinler', 'Asacıklar', 'Torbalar', 'Oklar', 'Cıvatalar', 'Mermiler',
        'Dartlar', 'Ara', 'Kullanılabilir', 'Alınabilir', 'Sıralama: %s', 'Oto', 'Tür', 'Fiyat', 'Ad', 'Satın al',
        'Tamam', 'Sat / normal görünüm', 'Büyük tüccar', '%d ap', 'Sınırsız', '%d stokta', 'Kaynak: %s', 'Dilekler',
        '%d eşya', 'Henüz bir şey yok: tüccarı doldurmak için dükkânları gez.', 'Yeterli altın yok',
        'Sırt çantası dolu: başka bir karakter seç', 'Şu an satın alınamaz', 'Alındı: %s x%d',
        'Tık: seç. Ctrl + tık: dilek. Sağ tık: açıklama.', 'Toplam: %d ap', 'Pano: %s', 'iğnelenmiş ilanlar',
        'boyalı', 'İşaretlileri sat: %s ap', 'İşaretli yok', 'Zuladan satıldı: %d ap'],
    'ukrainian': [
        'Великий торговець', 'Усе', 'Зброя', 'Обладунки', 'Спорядження', 'Зілля', 'Сувої', 'Самоцвіти', 'Набої',
        'Різне', 'Луки', 'Арбалети', 'Пращі', 'Кинджали', 'Короткі мечі', 'Довгі мечі', 'Півтораручні мечі',
        'Дворучні мечі', 'Катани', 'Ятагани', 'Сокири', 'Булави', 'Бойові молоти', 'Ціпи, моргенштерни', 'Палиці',
        'Посохи', 'Списи', 'Алебарди', 'Кулачна зброя', 'Мантії', 'Шкіряні', 'Кольчужні', 'Латні', 'Інші обладунки',
        'Щити', 'Шоломи', 'Наручі, рукавиці', 'Персні', 'Амулети', 'Пояси', 'Чоботи', 'Плащі', 'Жезли', 'Торби',
        'Стріли', 'Болти', 'Кулі', 'Дротики', 'Пошук', 'Можна носити', 'По кишені', 'Сортування: %s', 'Авто', 'Тип',
        'Ціна', "Ім'я", 'Купити', 'Готово', 'Продати / звичайний вигляд', 'Великий торговець', '%d зм',
        'Без обмежень', '%d в наявності', 'Від: %s', 'Бажане', 'Предметів: %d',
        'Поки порожньо: відвідайте крамниці, щоб поповнити товар.', 'Бракує золота',
        'Наплічник повний: виберіть іншого героя', 'Зараз це не купити', 'Куплено: %s x%d',
        'Клік: вибрати. Ctrl + клік: бажане. Правий клік: опис.', 'Разом: %d зм', 'Дошка: %s',
        'приколоті оголошення', 'мальована', 'Продати позначене: %s зм', 'Нічого не позначено',
        'Продано зі схованки: %d зм'],
    'schinese': [
        '营地商人', '全部', '武器', '护甲', '装备', '药水', '卷轴', '宝石', '弹药', '杂物', '弓', '弩', '投石索', '匕首',
        '短剑', '长剑', '重剑', '双手剑', '武士刀', '弯刀', '斧', '钉锤', '战锤', '连枷、晨星锤', '棍棒', '长棍', '矛',
        '戟', '拳套武器', '法袍', '皮甲', '链甲', '板甲', '其他护甲', '盾牌', '头盔', '护腕、护手', '戒指', '护身符',
        '腰带', '靴子', '斗篷', '魔杖', '袋子', '箭', '弩矢', '弹丸', '飞镖', '搜索', '可用', '买得起', '排序：%s',
        '自动', '类型', '价格', '名称', '购买', '完成', '出售 / 普通界面', '营地商人', '%d 金币', '无限', '库存 %d',
        '来自：%s', '心愿单', '%d 件物品', '暂无商品：去拜访商店来充实营地商人。', '金币不足',
        '背包已满：请选择其他角色', '现在无法购买', '已购买：%s x%d', '单击：选择。Ctrl + 单击：心愿单。右键：说明。',
        '总计：%d 金币', '告示板：%s', '钉着的告示', '彩绘', '出售已标记：%s 金币', '没有标记的物品',
        '已从储藏箱出售：%d 金币'],
    'japanese': [
        'キャンプ商人', 'すべて', '武器', '鎧', '装備品', 'ポーション', 'スクロール', '宝石', '弾薬', 'その他', '弓',
        'クロスボウ', 'スリング', 'ダガー', 'ショートソード', 'ロングソード', 'バスタードソード', 'ツーハンデッドソード',
        '刀', 'シミター', '斧', 'メイス', 'ウォーハンマー', 'フレイル、モーニングスター', 'クラブ', 'クォータースタッフ',
        'スピア', 'ハルバード', '拳武器', 'ローブ', 'レザー', 'メイル', 'プレート', 'その他の鎧', '盾', '兜',
        'ブレーサー、ガントレット', '指輪', 'アミュレット', 'ベルト', 'ブーツ', 'クローク', 'ワンド', '袋', '矢',
        'ボルト', '弾丸', 'ダート', '検索', '使用可能', '購入可能', '並べ替え: %s', '自動', '種類', '価格', '名前',
        '購入', '完了', '売却 / 通常表示', 'キャンプ商人', '%d GP', '無制限', '在庫 %d', '入手元: %s', 'ほしいもの',
        '%d 個', 'まだ何もありません: 店を訪れてキャンプ商人を充実させましょう。', 'ゴールドが足りません',
        'バックパックが満杯です: 別のキャラクターを選んでください', '今は購入できません', '購入: %s x%d',
        'クリック: 選択。Ctrl + クリック: ほしいもの。右クリック: 説明。', '合計: %d GP', '掲示板: %s',
        'ピン留めの張り紙', '彩色', '印を売却: %s GP', '印なし', '収納箱から売却: %d GP'],
    'korean': [
        '야영지 상인', '전체', '무기', '갑옷', '장비', '물약', '두루마리', '보석', '탄약', '기타', '활', '석궁', '투석구',
        '단검', '소검', '장검', '바스타드 소드', '양손검', '카타나', '시미터', '도끼', '메이스', '워해머',
        '플레일, 모닝스타', '곤봉', '쿼터스태프', '창', '할버드', '주먹 무기', '로브', '가죽', '사슬', '판금',
        '기타 갑옷', '방패', '투구', '팔보호구, 건틀릿', '반지', '목걸이', '허리띠', '장화', '망토', '완드', '가방',
        '화살', '석궁 화살', '탄환', '다트', '검색', '사용 가능', '구입 가능', '정렬: %s', '자동', '종류', '가격',
        '이름', '구입', '완료', '판매 / 기본 화면', '야영지 상인', '%d 골드', '무제한', '재고 %d', '출처: %s', '찜 목록',
        '물품 %d개', '아직 없습니다: 상점을 방문해 야영지 상인을 채우세요.', '골드가 부족합니다',
        '배낭이 가득 찼습니다: 다른 캐릭터를 고르세요', '지금은 구입할 수 없습니다', '구입함: %s x%d',
        '클릭: 선택. Ctrl + 클릭: 찜. 오른쪽 클릭: 설명.', '합계: %d 골드', '게시판: %s', '핀으로 꽂은 공고',
        '채색', '표시한 물건 판매: %s 골드', '표시한 것 없음', '보관함에서 판매: %d 골드'],
}

# The camp chest (2026-10-23): French for now, the other languages fall back to English.
EXTRA = {
    'french': {
        'gm_chest': 'Codex', 'gm_stash': 'Coffre du groupe', 'gm_take': 'Prendre',
        'gm_in_stash': '%d dans le coffre', 'gm_value': 'Valeur : %d po', 'gm_never_seen': 'Jamais vu',
        'gm_seen_1': 'Vu en vente : %s', 'gm_seen_2': 'Porté : %s', 'gm_seen_3': 'Vu au sol : %s',
        'gm_seen_4': 'Vu dans un conteneur : %s', 'gm_origin': 'Provenance :', 'gm_more': '+%d autres',
        'gm_from_S': 'Vendu par %s', 'gm_from_G': '%s : au sol', 'gm_from_C': '%s : %s',
        'gm_from_K': 'Porté par %s à %s', 'gm_from_K0': 'Porté par %s', 'gm_from_G0': 'Au sol', 'gm_camp_7': 'Ailleurs', 'gm_cf_7': 'Autre', 'gm_cf_8': 'Porté', 'gm_cf_9': 'Trouvé', 'gm_cf_10': 'Pas trouvé',
        'gm_equipped_by': 'Équipé par %s', 'gm_in_pack': 'Dans le sac de %s',
        'gm_from_D': 'Donné par %s à %s', 'gm_from_D1': 'Donné par %s', 'gm_from_D2': 'Donné à %s',
        'gm_from_D0': "Donné lors d'une quête ou d'un dialogue", 'gm_from_P': 'Porté par %s (apparaît) à %s',
        'gm_from_P0': 'Porté par %s (apparaît)', 'gm_from_T': 'Trésor aléatoire',
        'gm_from_C0': 'Conteneur : %s', 'gm_from_S2': 'Vendu à %s : %s', 'gm_at': '%s, %s',
        'gm_ctype': 'conteneur', 'gm_ctype_1': 'sac', 'gm_ctype_2': 'coffre', 'gm_ctype_3': 'tiroir',
        'gm_ctype_5': 'table', 'gm_ctype_6': 'étagère', 'gm_ctype_7': 'autel', 'gm_ctype_8': 'cachette',
        'gm_ctype_9': 'grimoire', 'gm_ctype_10': 'corps', 'gm_ctype_11': 'tonneau', 'gm_ctype_12': 'caisse'},
}

# the Codex strings in the other languages (2026-10-28, v1.0.2: translated for SadoEE), {language: {key: text}}
_extra = os.path.join(HERE, 'gm_strings_extra.json')
if os.path.exists(_extra):
    import json
    for _lang, _d in json.load(open(_extra, encoding='utf-8')).items():
        EXTRA.setdefault(_lang, {}).update(_d)


def lua_str(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('\n', '\\n') + "'"


def one_per_line(s):
    """The help on the item card: one action per line (John 2026-10-23), the sentences' final stops dropped."""
    for stop in ('。', '. '):
        s = s.replace(stop, '\n')
    return s.rstrip('.。\n ')


def main():
    for lang, vals in T.items():
        assert len(vals) == len(KEYS), (lang, len(vals), len(KEYS))
        for k, v in zip(KEYS, vals):  # same placeholders as English
            assert v.count('%') == {'gm_sort': 1, 'gm_price': 1, 'gm_stock': 1, 'gm_from': 1, 'gm_items': 1,
                                    'gm_bought': 2, 'gm_total': 1, 'gm_skin': 1, 'gm_sell_marked': 1,
                                    'gm_sold': 1}.get(k, 0), (lang, k, v)
        lines = ['-- Generated by build_gm_strings.py: the camp merchant page in %s (M_PSXGM.lua reads it).' % lang,
                 'PSXGM_Strings = {']
        for k, v in zip(KEYS, vals):
            if k == 'gm_select':
                v = one_per_line(v)
            lines.append('\t%s = %s,' % (k, lua_str(v)))
        for k, v in EXTRA.get(lang, {}).items():
            lines.append('\t%s = %s,' % (k, lua_str(v)))
        lines.append('}')
        out = os.path.join(HERE, 'tra', lang, 'M_PSXGT.lua')
        with open(out, 'w', encoding='utf-8', newline='\n') as f:
            f.write('\n'.join(lines) + '\n')
    print(len(T), 'languages written')


if __name__ == '__main__':
    main()
