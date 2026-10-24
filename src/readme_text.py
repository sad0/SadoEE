"""SadoEE readme prose, per language (build_sadoee.py writes readme/readme-<language>.html).

The component list is not here: it is read from SadoEE.tp2 and the installed language's .tra files, so it is always
complete and translated. A language missing here uses English prose around its translated component list.
"""

TEXT = {}
TEXT['english'] = dict(
    lang='en',
    intro='Party Stash and SadoQoL in one mod: a shared infinite stash on a redesigned inventory page, a rest camp '
          'with its merchant, scholar and lich, a party of up to 32, and many quality-of-life tweaks. Every feature is '
          'an optional component.',
    h_components='Components', c_num='#', c_name='Component', experimental='experimental',
    h_compat='Compatibility', compat_head=('', 'BGEE', 'EET', 'BG2EE'),
    compat=[('Party Stash, sorted loot, options (#0-#7)', 'yes', 'yes', 'yes'),
            ('Rest camp and its people (#10-#15)', 'yes', 'yes', 'not yet'),
            ('Quality of life (#20-#32)', 'yes', 'yes', 'yes'),
            ('Big party, 7 to 32 members (#40)', 'yes', 'yes', 'no')],
    compat_note='Game versions 2.6.6 and 2.7.3. EEex is required by every component.',
    h_install='Installation', install=[
        'Install EEex.',
        'Extract the archive into the game folder (where chitin.key is).',
        'Run setup-SadoEE.exe, pick your language and the components you want.',
        'Start the game with InfinityLoader.exe (EEex).'],
    h_upgrade='Coming from Party Stash or SadoQoL',
    upgrade='SadoEE replaces both mods (same files): uninstall every Party Stash and SadoQoL component first, then '
            'install SadoEE. Your saves keep working: the stash contents, the camp and its people keep their names.',
    h_uninstall='Uninstalling',
    uninstall='Empty the stash first, in game: Ctrl + left click on the big bag next to the weight. Otherwise its '
              'contents stay in your saves but cannot be reached until the stash is installed again. With the big '
              'party, bring the party back to 6 members or fewer before uninstalling #40.',
    h_help='In game', help='The gold ? button on the inventory page explains every part of the stash page. The '
                           'camp is reached from the world map: the parchment above the Travel button.',
    h_license='License', license='MIT. Author: sad0.')

TEXT['french'] = dict(
    lang='fr',
    intro='Party Stash et SadoQoL en un seul mod : un coffre infini partagé sur une page d\'inventaire repensée, un '
          'camp de repos avec son marchand, son lettré et sa liche, un groupe jusqu\'à 32 et de nombreux réglages de '
          'confort. Chaque fonction est un composant optionnel.',
    h_components='Composants', c_num='#', c_name='Composant', experimental='expérimental',
    h_compat='Compatibilité', compat_head=('', 'BGEE', 'EET', 'BG2EE'),
    compat=[('Party Stash, butin trié, options (#0-#7)', 'oui', 'oui', 'oui'),
            ('Camp de repos et ses habitants (#10-#15)', 'oui', 'oui', 'pas encore'),
            ('Confort de jeu (#20-#32)', 'oui', 'oui', 'oui'),
            ('Grand groupe, 7 à 32 membres (#40)', 'oui', 'oui', 'non')],
    compat_note='Versions du jeu 2.6.6 et 2.7.3. Tous les composants nécessitent EEex.',
    h_install='Installation', install=[
        'Installez EEex.',
        'Extrayez l\'archive dans le dossier du jeu (là où se trouve chitin.key).',
        'Lancez setup-SadoEE.exe, choisissez votre langue et les composants voulus.',
        'Lancez le jeu avec InfinityLoader.exe (EEex).'],
    h_upgrade='Si vous aviez Party Stash ou SadoQoL',
    upgrade='SadoEE remplace ces deux mods (mêmes fichiers) : désinstallez d\'abord tous les composants de Party Stash '
            'et de SadoQoL, puis installez SadoEE. Vos sauvegardes continuent de fonctionner : le contenu du coffre, le '
            'camp et ses habitants gardent leurs noms.',
    h_uninstall='Désinstallation',
    uninstall='Videz d\'abord le coffre, en jeu : Ctrl + clic gauche sur le gros sac à côté du poids. Sinon son '
              'contenu reste dans vos sauvegardes mais est inaccessible tant que le coffre n\'est pas réinstallé. Avec '
              'le grand groupe, revenez à 6 membres ou moins avant de désinstaller le #40.',
    h_help='En jeu', help='Le bouton ? doré de la page d\'inventaire explique chaque partie du coffre. Le camp '
                          's\'atteint depuis la carte du monde : le parchemin au-dessus du bouton Voyager.',
    h_license='Licence', license='MIT. Auteur : sad0.')

TEXT['german'] = dict(
    lang='de',
    intro='Party Stash und SadoQoL in einem Mod: eine gemeinsame, unendliche Truhe auf einer neu gestalteten '
          'Inventarseite, ein Rastlager mit Händler, Gelehrtem und Lich, eine Gruppe mit bis zu 32 Mitgliedern und '
          'viele Komfortfunktionen. Jede Funktion ist eine optionale Komponente.',
    h_components='Komponenten', c_num='#', c_name='Komponente', experimental='experimentell',
    h_compat='Kompatibilität', compat_head=('', 'BGEE', 'EET', 'BG2EE'),
    compat=[('Party Stash, sortierte Beute, Optionen (#0-#7)', 'ja', 'ja', 'ja'),
            ('Rastlager und seine Bewohner (#10-#15)', 'ja', 'ja', 'noch nicht'),
            ('Komfortfunktionen (#20-#32)', 'ja', 'ja', 'ja'),
            ('Große Gruppe, 7 bis 32 Mitglieder (#40)', 'ja', 'ja', 'nein')],
    compat_note='Spielversionen 2.6.6 und 2.7.3. Jede Komponente benötigt EEex.',
    h_install='Installation', install=[
        'Installiert EEex.',
        'Entpackt das Archiv in den Spielordner (dort, wo chitin.key liegt).',
        'Startet setup-SadoEE.exe und wählt eure Sprache und die gewünschten Komponenten.',
        'Startet das Spiel mit InfinityLoader.exe (EEex).'],
    h_upgrade='Umstieg von Party Stash oder SadoQoL',
    upgrade='SadoEE ersetzt beide Mods (dieselben Dateien): deinstalliert zuerst alle Komponenten von Party Stash und '
            'SadoQoL, dann installiert SadoEE. Eure Spielstände funktionieren weiter: Truheninhalt, Lager und Bewohner '
            'behalten ihre Namen.',
    h_uninstall='Deinstallation',
    uninstall='Leert zuerst die Truhe im Spiel: Strg + Linksklick auf den großen Beutel neben dem Gewicht. Sonst bleibt '
              'ihr Inhalt in euren Spielständen, ist aber unerreichbar, bis die Truhe wieder installiert ist. Mit der '
              'großen Gruppe: verkleinert sie vor der Deinstallation von #40 auf 6 Mitglieder oder weniger.',
    h_help='Im Spiel', help='Die goldene ?-Schaltfläche auf der Inventarseite erklärt jeden Teil der Truhenseite. Das '
                            'Lager erreicht ihr über die Weltkarte: das Pergament über der Schaltfläche Reisen.',
    h_license='Lizenz', license='MIT. Autor: sad0.')

TEXT['spanish'] = dict(
    lang='es',
    intro='Party Stash y SadoQoL en un solo mod: un baúl infinito compartido en una página de inventario rediseñada, '
          'un campamento de descanso con su mercader, su erudito y su liche, un grupo de hasta 32 miembros y muchas '
          'mejoras de comodidad. Cada función es un componente opcional.',
    h_components='Componentes', c_num='#', c_name='Componente', experimental='experimental',
    h_compat='Compatibilidad', compat_head=('', 'BGEE', 'EET', 'BG2EE'),
    compat=[('Party Stash, botín ordenado, opciones (#0-#7)', 'sí', 'sí', 'sí'),
            ('Campamento de descanso y sus habitantes (#10-#15)', 'sí', 'sí', 'aún no'),
            ('Comodidad de juego (#20-#32)', 'sí', 'sí', 'sí'),
            ('Grupo grande, de 7 a 32 miembros (#40)', 'sí', 'sí', 'no')],
    compat_note='Versiones del juego 2.6.6 y 2.7.3. Todos los componentes requieren EEex.',
    h_install='Instalación', install=[
        'Instala EEex.',
        'Extrae el archivo comprimido en la carpeta del juego (donde está chitin.key).',
        'Ejecuta setup-SadoEE.exe y elige tu idioma y los componentes que quieras.',
        'Inicia el juego con InfinityLoader.exe (EEex).'],
    h_upgrade='Si vienes de Party Stash o SadoQoL',
    upgrade='SadoEE sustituye a ambos mods (mismos archivos): desinstala primero todos los componentes de Party Stash y '
            'SadoQoL, y después instala SadoEE. Tus partidas guardadas siguen funcionando: el contenido del baúl, el '
            'campamento y sus habitantes conservan sus nombres.',
    h_uninstall='Desinstalación',
    uninstall='Vacía primero el baúl, en el juego: Ctrl + clic izquierdo en la bolsa grande junto al peso. Si no, su '
              'contenido sigue en tus partidas guardadas pero queda inaccesible hasta que vuelvas a instalar el baúl. '
              'Con el grupo grande, vuelve a 6 miembros o menos antes de desinstalar el #40.',
    h_help='En el juego', help='El botón ? dorado de la página de inventario explica cada parte de la página del baúl. '
                               'Al campamento se llega desde el mapa del mundo: el pergamino sobre el botón Viajar.',
    h_license='Licencia', license='MIT. Autor: sad0.')

TEXT['italian'] = dict(
    lang='it',
    intro="Party Stash e SadoQoL in un unico mod: un baule infinito condiviso su una pagina dell'inventario "
          "ridisegnata, un campo di riposo con il suo mercante, il suo erudito e il suo lich, un gruppo fino a 32 "
          "membri e tante comodità di gioco. Ogni funzione è un componente opzionale.",
    h_components='Componenti', c_num='#', c_name='Componente', experimental='sperimentale',
    h_compat='Compatibilità', compat_head=('', 'BGEE', 'EET', 'BG2EE'),
    compat=[('Party Stash, bottino ordinato, opzioni (#0-#7)', 'sì', 'sì', 'sì'),
            ('Campo di riposo e i suoi abitanti (#10-#15)', 'sì', 'sì', 'non ancora'),
            ('Comodità di gioco (#20-#32)', 'sì', 'sì', 'sì'),
            ('Gruppo grande, da 7 a 32 membri (#40)', 'sì', 'sì', 'no')],
    compat_note='Versioni del gioco 2.6.6 e 2.7.3. Tutti i componenti richiedono EEex.',
    h_install='Installazione', install=[
        'Installa EEex.',
        "Estrai l'archivio nella cartella del gioco (dove si trova chitin.key).",
        'Avvia setup-SadoEE.exe e scegli la lingua e i componenti desiderati.',
        'Avvia il gioco con InfinityLoader.exe (EEex).'],
    h_upgrade='Se avevi Party Stash o SadoQoL',
    upgrade='SadoEE sostituisce entrambi i mod (stessi file): disinstalla prima tutti i componenti di Party Stash e '
            'SadoQoL, poi installa SadoEE. I salvataggi continuano a funzionare: il contenuto del baule, il campo e i '
            'suoi abitanti mantengono i loro nomi.',
    h_uninstall='Disinstallazione',
    uninstall='Prima svuota il baule, in gioco: Ctrl + clic sinistro sulla grande borsa accanto al peso. Altrimenti il '
              'suo contenuto resta nei salvataggi ma è inaccessibile finché il baule non viene reinstallato. Con il '
              'gruppo grande, torna a 6 membri o meno prima di disinstallare il #40.',
    h_help='In gioco', help="Il pulsante ? dorato nella pagina dell'inventario spiega ogni parte della pagina del "
                            "baule. Il campo si raggiunge dalla mappa del mondo: la pergamena sopra il pulsante Viaggia.",
    h_license='Licenza', license='MIT. Autore: sad0.')

TEXT['polish'] = dict(
    lang='pl',
    intro='Party Stash i SadoQoL w jednym modzie: wspólna, nieskończona skrzynia na przeprojektowanej stronie '
          'ekwipunku, obóz odpoczynku z kupcem, uczonym i liszem, drużyna do 32 osób oraz wiele udogodnień. Każda '
          'funkcja to opcjonalny komponent.',
    h_components='Komponenty', c_num='#', c_name='Komponent', experimental='eksperymentalny',
    h_compat='Zgodność', compat_head=('', 'BGEE', 'EET', 'BG2EE'),
    compat=[('Party Stash, posortowane łupy, opcje (#0-#7)', 'tak', 'tak', 'tak'),
            ('Obóz odpoczynku i jego mieszkańcy (#10-#15)', 'tak', 'tak', 'jeszcze nie'),
            ('Udogodnienia (#20-#32)', 'tak', 'tak', 'tak'),
            ('Duża drużyna, od 7 do 32 członków (#40)', 'tak', 'tak', 'nie')],
    compat_note='Wersje gry 2.6.6 i 2.7.3. Każdy komponent wymaga EEex.',
    h_install='Instalacja', install=[
        'Zainstaluj EEex.',
        'Wypakuj archiwum do folderu gry (tam, gdzie jest chitin.key).',
        'Uruchom setup-SadoEE.exe, wybierz język i potrzebne komponenty.',
        'Uruchamiaj grę przez InfinityLoader.exe (EEex).'],
    h_upgrade='Przejście z Party Stash lub SadoQoL',
    upgrade='SadoEE zastępuje oba mody (te same pliki): najpierw odinstaluj wszystkie komponenty Party Stash i SadoQoL, '
            'potem zainstaluj SadoEE. Twoje zapisy nadal działają: zawartość skrzyni, obóz i jego mieszkańcy '
            'zachowują swoje nazwy.',
    h_uninstall='Odinstalowanie',
    uninstall='Najpierw opróżnij skrzynię w grze: Ctrl + lewy przycisk na dużej torbie obok wagi. W przeciwnym razie '
              'jej zawartość zostaje w zapisach, ale jest niedostępna, dopóki skrzynia nie zostanie ponownie '
              'zainstalowana. Przy dużej drużynie zmniejsz ją do 6 członków lub mniej przed odinstalowaniem #40.',
    h_help='W grze', help='Złoty przycisk ? na stronie ekwipunku objaśnia każdą część strony skrzyni. Do obozu '
                          'dotrzesz z mapy świata: pergamin nad przyciskiem Podróż.',
    h_license='Licencja', license='MIT. Autor: sad0.')

TEXT['russian'] = dict(
    lang='ru',
    intro='Party Stash и SadoQoL в одном моде: общий бесконечный сундук на переработанной странице инвентаря, лагерь '
          'для отдыха с торговцем, учёным и личем, отряд до 32 человек и множество улучшений удобства. Каждая '
          'функция — необязательный компонент.',
    h_components='Компоненты', c_num='#', c_name='Компонент', experimental='экспериментальный',
    h_compat='Совместимость', compat_head=('', 'BGEE', 'EET', 'BG2EE'),
    compat=[('Party Stash, отсортированная добыча, опции (#0-#7)', 'да', 'да', 'да'),
            ('Лагерь для отдыха и его обитатели (#10-#15)', 'да', 'да', 'пока нет'),
            ('Удобство игры (#20-#32)', 'да', 'да', 'да'),
            ('Большой отряд, от 7 до 32 человек (#40)', 'да', 'да', 'нет')],
    compat_note='Версии игры 2.6.6 и 2.7.3. Для всех компонентов требуется EEex.',
    h_install='Установка', install=[
        'Установите EEex.',
        'Распакуйте архив в папку игры (где лежит chitin.key).',
        'Запустите setup-SadoEE.exe, выберите язык и нужные компоненты.',
        'Запускайте игру через InfinityLoader.exe (EEex).'],
    h_upgrade='Переход с Party Stash или SadoQoL',
    upgrade='SadoEE заменяет оба мода (те же файлы): сначала удалите все компоненты Party Stash и SadoQoL, затем '
            'установите SadoEE. Ваши сохранения продолжат работать: содержимое сундука, лагерь и его обитатели '
            'сохраняют свои имена.',
    h_uninstall='Удаление',
    uninstall='Сначала опустошите сундук в игре: Ctrl + левый щелчок по большой сумке рядом с весом. Иначе его '
              'содержимое останется в сохранениях, но будет недоступно, пока сундук не будет установлен снова. С '
              'большим отрядом перед удалением #40 сократите его до 6 человек или меньше.',
    h_help='В игре', help='Золотая кнопка ? на странице инвентаря объясняет каждую часть страницы сундука. В лагерь '
                          'можно попасть с карты мира: пергамент над кнопкой «Путешествовать».',
    h_license='Лицензия', license='MIT. Автор: sad0.')

TEXT['portuguese'] = dict(
    lang='pt-BR',
    intro='Party Stash e SadoQoL em um só mod: um baú infinito compartilhado em uma página de inventário redesenhada, '
          'um acampamento de descanso com seu mercador, seu erudito e seu lich, um grupo de até 32 membros e muitas '
          'melhorias de qualidade de vida. Cada função é um componente opcional.',
    h_components='Componentes', c_num='#', c_name='Componente', experimental='experimental',
    h_compat='Compatibilidade', compat_head=('', 'BGEE', 'EET', 'BG2EE'),
    compat=[('Party Stash, saque ordenado, opções (#0-#7)', 'sim', 'sim', 'sim'),
            ('Acampamento de descanso e seus habitantes (#10-#15)', 'sim', 'sim', 'ainda não'),
            ('Qualidade de vida (#20-#32)', 'sim', 'sim', 'sim'),
            ('Grupo grande, de 7 a 32 membros (#40)', 'sim', 'sim', 'não')],
    compat_note='Versões do jogo 2.6.6 e 2.7.3. Todos os componentes exigem o EEex.',
    h_install='Instalação', install=[
        'Instale o EEex.',
        'Extraia o arquivo compactado na pasta do jogo (onde fica o chitin.key).',
        'Execute o setup-SadoEE.exe e escolha seu idioma e os componentes desejados.',
        'Inicie o jogo pelo InfinityLoader.exe (EEex).'],
    h_upgrade='Vindo do Party Stash ou do SadoQoL',
    upgrade='O SadoEE substitui os dois mods (mesmos arquivos): desinstale antes todos os componentes do Party Stash e '
            'do SadoQoL, depois instale o SadoEE. Seus saves continuam funcionando: o conteúdo do baú, o acampamento e '
            'seus habitantes mantêm os nomes.',
    h_uninstall='Desinstalação',
    uninstall='Esvazie o baú antes, no jogo: Ctrl + clique esquerdo na bolsa grande ao lado do peso. Caso contrário, o '
              'conteúdo fica nos seus saves, mas inacessível até o baú ser reinstalado. Com o grupo grande, volte a 6 '
              'membros ou menos antes de desinstalar o #40.',
    h_help='No jogo', help='O botão ? dourado da página de inventário explica cada parte da página do baú. O '
                           'acampamento é acessado pelo mapa-múndi: o pergaminho acima do botão Viajar.',
    h_license='Licença', license='MIT. Autor: sad0.')

TEXT['czech'] = dict(
    lang='cs',
    intro='Party Stash a SadoQoL v jednom modu: sdílená nekonečná truhla na přepracované stránce inventáře, '
          'odpočinkový tábor s kupcem, učencem a lichem, družina až o 32 členech a spousta vylepšení pohodlí. Každá '
          'funkce je volitelná komponenta.',
    h_components='Komponenty', c_num='#', c_name='Komponenta', experimental='experimentální',
    h_compat='Kompatibilita', compat_head=('', 'BGEE', 'EET', 'BG2EE'),
    compat=[('Party Stash, seřazená kořist, možnosti (#0-#7)', 'ano', 'ano', 'ano'),
            ('Odpočinkový tábor a jeho obyvatelé (#10-#15)', 'ano', 'ano', 'zatím ne'),
            ('Pohodlí hry (#20-#32)', 'ano', 'ano', 'ano'),
            ('Velká družina, 7 až 32 členů (#40)', 'ano', 'ano', 'ne')],
    compat_note='Verze hry 2.6.6 a 2.7.3. Všechny komponenty vyžadují EEex.',
    h_install='Instalace', install=[
        'Nainstalujte EEex.',
        'Rozbalte archiv do složky hry (kde je chitin.key).',
        'Spusťte setup-SadoEE.exe, zvolte jazyk a požadované komponenty.',
        'Spouštějte hru přes InfinityLoader.exe (EEex).'],
    h_upgrade='Přechod z Party Stash nebo SadoQoL',
    upgrade='SadoEE nahrazuje oba mody (stejné soubory): nejprve odinstalujte všechny komponenty Party Stash a SadoQoL, '
            'pak nainstalujte SadoEE. Vaše uložené pozice dál fungují: obsah truhly, tábor a jeho obyvatelé si '
            'ponechávají svá jména.',
    h_uninstall='Odinstalace',
    uninstall='Nejprve ve hře vyprázdněte truhlu: Ctrl + levé kliknutí na velký vak vedle váhy. Jinak její obsah '
              'zůstane v uložených pozicích, ale bude nedostupný, dokud truhlu znovu nenainstalujete. S velkou družinou '
              'ji před odinstalováním #40 zmenšete na 6 členů nebo méně.',
    h_help='Ve hře', help='Zlaté tlačítko ? na stránce inventáře vysvětluje každou část stránky truhly. Do tábora se '
                          'dostanete z mapy světa: pergamen nad tlačítkem Cestovat.',
    h_license='Licence', license='MIT. Autor: sad0.')

TEXT['hungarian'] = dict(
    lang='hu',
    intro='A Party Stash és a SadoQoL egyetlen modban: közös, végtelen láda egy újratervezett felszerelés oldalon, '
          'pihenőtábor kereskedővel, tudóssal és lichhel, legfeljebb 32 fős csapat és számos kényelmi funkció. Minden '
          'funkció külön választható komponens.',
    h_components='Komponensek', c_num='#', c_name='Komponens', experimental='kísérleti',
    h_compat='Kompatibilitás', compat_head=('', 'BGEE', 'EET', 'BG2EE'),
    compat=[('Party Stash, rendezett zsákmány, beállítások (#0-#7)', 'igen', 'igen', 'igen'),
            ('Pihenőtábor és lakói (#10-#15)', 'igen', 'igen', 'még nem'),
            ('Kényelmi funkciók (#20-#32)', 'igen', 'igen', 'igen'),
            ('Nagy csapat, 7-32 tag (#40)', 'igen', 'igen', 'nem')],
    compat_note='Játékverziók: 2.6.6 és 2.7.3. Minden komponenshez EEex szükséges.',
    h_install='Telepítés', install=[
        'Telepítsd az EEex-et.',
        'Csomagold ki az archívumot a játék mappájába (ahol a chitin.key van).',
        'Futtasd a setup-SadoEE.exe-t, válaszd ki a nyelvet és a kívánt komponenseket.',
        'Indítsd a játékot az InfinityLoader.exe-vel (EEex).'],
    h_upgrade='Áttérés a Party Stash-ről vagy a SadoQoL-ről',
    upgrade='A SadoEE mindkét modot felváltja (ugyanazok a fájlok): előbb távolítsd el a Party Stash és a SadoQoL '
            'összes komponensét, aztán telepítsd a SadoEE-t. A mentéseid továbbra is működnek: a láda tartalma, a '
            'tábor és lakói megtartják a nevüket.',
    h_uninstall='Eltávolítás',
    uninstall='Előbb ürítsd ki a ládát a játékban: Ctrl + bal kattintás a súly melletti nagy zsákra. Különben a '
              'tartalma a mentéseidben marad, de elérhetetlen, amíg a ládát újra nem telepíted. Nagy csapattal a #40 '
              'eltávolítása előtt csökkentsd a csapatot 6 főre vagy kevesebbre.',
    h_help='A játékban', help='A felszerelés oldal arany ? gombja elmagyarázza a ládaoldal minden részét. A tábor a '
                              'világtérképről érhető el: az Utazás gomb feletti pergamen.',
    h_license='Licenc', license='MIT. Szerző: sad0.')

TEXT['turkish'] = dict(
    lang='tr',
    intro="Party Stash ve SadoQoL tek bir modda: yeniden tasarlanmış envanter sayfasında ortak ve sonsuz bir sandık; "
          "tüccarı, âlimi ve lich'iyle bir dinlenme kampı; 32 kişiye kadar bir grup ve birçok yaşam kalitesi "
          "iyileştirmesi. Her özellik isteğe bağlı bir bileşendir.",
    h_components='Bileşenler', c_num='#', c_name='Bileşen', experimental='deneysel',
    h_compat='Uyumluluk', compat_head=('', 'BGEE', 'EET', 'BG2EE'),
    compat=[('Party Stash, sıralı ganimet, seçenekler (#0-#7)', 'evet', 'evet', 'evet'),
            ('Dinlenme kampı ve sakinleri (#10-#15)', 'evet', 'evet', 'henüz değil'),
            ('Yaşam kalitesi (#20-#32)', 'evet', 'evet', 'evet'),
            ('Büyük grup, 7 ila 32 üye (#40)', 'evet', 'evet', 'hayır')],
    compat_note='Oyun sürümleri 2.6.6 ve 2.7.3. Tüm bileşenler EEex gerektirir.',
    h_install='Kurulum', install=[
        "EEex'i kurun.",
        'Arşivi oyun klasörüne çıkarın (chitin.key dosyasının bulunduğu yer).',
        "setup-SadoEE.exe'yi çalıştırın, dilinizi ve istediğiniz bileşenleri seçin.",
        'Oyunu InfinityLoader.exe (EEex) ile başlatın.'],
    h_upgrade="Party Stash veya SadoQoL'dan geçiş",
    upgrade="SadoEE iki modun da yerini alır (aynı dosyalar): önce Party Stash ve SadoQoL'un tüm bileşenlerini "
            "kaldırın, sonra SadoEE'yi kurun. Kayıtlarınız çalışmaya devam eder: sandığın içeriği, kamp ve sakinleri "
            "adlarını korur.",
    h_uninstall='Kaldırma',
    uninstall="Önce oyunda sandığı boşaltın: ağırlığın yanındaki büyük çantaya Ctrl + sol tık. Aksi halde içeriği "
              "kayıtlarınızda kalır ama sandık yeniden kurulana kadar erişilemez. Büyük grupla, #40'ı kaldırmadan önce "
              "grubu 6 üyeye veya daha azına indirin.",
    h_help='Oyunda', help='Envanter sayfasındaki altın ? düğmesi sandık sayfasının her bölümünü açıklar. Kampa dünya '
                          'haritasından ulaşılır: Seyahat düğmesinin üstündeki parşömen.',
    h_license='Lisans', license='MIT. Yazar: sad0.')

TEXT['ukrainian'] = dict(
    lang='uk',
    intro='Party Stash і SadoQoL в одному моді: спільна нескінченна скриня на оновленій сторінці спорядження, табір '
          'відпочинку з торговцем, ученим і лічем, загін до 32 осіб і безліч покращень зручності. Кожна функція — '
          'необов’язковий компонент.',
    h_components='Компоненти', c_num='#', c_name='Компонент', experimental='експериментальний',
    h_compat='Сумісність', compat_head=('', 'BGEE', 'EET', 'BG2EE'),
    compat=[('Party Stash, відсортована здобич, опції (#0-#7)', 'так', 'так', 'так'),
            ('Табір відпочинку та його мешканці (#10-#15)', 'так', 'так', 'поки ні'),
            ('Зручність гри (#20-#32)', 'так', 'так', 'так'),
            ('Великий загін, від 7 до 32 осіб (#40)', 'так', 'так', 'ні')],
    compat_note='Версії гри 2.6.6 і 2.7.3. Усі компоненти потребують EEex.',
    h_install='Встановлення', install=[
        'Встановіть EEex.',
        'Розпакуйте архів у теку гри (де лежить chitin.key).',
        'Запустіть setup-SadoEE.exe, виберіть мову та потрібні компоненти.',
        'Запускайте гру через InfinityLoader.exe (EEex).'],
    h_upgrade='Перехід із Party Stash або SadoQoL',
    upgrade='SadoEE замінює обидва моди (ті самі файли): спершу видаліть усі компоненти Party Stash і SadoQoL, потім '
            'встановіть SadoEE. Ваші збереження й далі працюють: вміст скрині, табір і його мешканці зберігають свої '
            'імена.',
    h_uninstall='Видалення',
    uninstall='Спершу спорожніть скриню в грі: Ctrl + лівий клік по великій торбі поруч із вагою. Інакше її вміст '
              'лишиться у збереженнях, але буде недоступний, доки скриню не встановлять знову. З великим загоном перед '
              'видаленням #40 зменште його до 6 осіб або менше.',
    h_help='У грі', help='Золота кнопка ? на сторінці спорядження пояснює кожну частину сторінки скрині. До табору '
                         'можна потрапити з мапи світу: пергамент над кнопкою «Подорожувати».',
    h_license='Ліцензія', license='MIT. Автор: sad0.')

TEXT['schinese'] = dict(
    lang='zh-Hans',
    intro='Party Stash 与 SadoQoL 合为一个模组：重新设计的物品栏页面上有一个全队共享的无限储物箱，休息营地里有商人、'
          '学者和巫妖，队伍最多 32 人，还有大量便利性改进。每项功能都是可选组件。',
    h_components='组件', c_num='#', c_name='组件', experimental='实验性',
    h_compat='兼容性', compat_head=('', 'BGEE', 'EET', 'BG2EE'),
    compat=[('Party Stash、战利品排序、选项 (#0-#7)', '是', '是', '是'),
            ('休息营地及其居民 (#10-#15)', '是', '是', '暂不支持'),
            ('便利性改进 (#20-#32)', '是', '是', '是'),
            ('大型队伍，7 至 32 人 (#40)', '是', '是', '否')],
    compat_note='游戏版本 2.6.6 和 2.7.3。所有组件都需要 EEex。',
    h_install='安装', install=[
        '安装 EEex。',
        '将压缩包解压到游戏文件夹（chitin.key 所在位置）。',
        '运行 setup-SadoEE.exe，选择语言和需要的组件。',
        '通过 InfinityLoader.exe (EEex) 启动游戏。'],
    h_upgrade='从 Party Stash 或 SadoQoL 升级',
    upgrade='SadoEE 取代这两个模组（使用相同文件）：请先卸载 Party Stash 和 SadoQoL 的所有组件，再安装 SadoEE。你的存档'
            '仍可正常使用：储物箱内容、营地及其居民都保留原有名称。',
    h_uninstall='卸载',
    uninstall='请先在游戏中清空储物箱：按住 Ctrl 并左键单击重量旁的大包袋。否则其内容会留在存档中，但在重新安装储物箱前'
              '无法取用。使用大型队伍时，卸载 #40 前请将队伍减至 6 人或更少。',
    h_help='游戏内', help='物品栏页面上的金色 ? 按钮会讲解储物箱页面的每个部分。营地从世界地图进入：“旅行”按钮上方的羊皮纸。',
    h_license='许可证', license='MIT。作者：sad0。')

TEXT['japanese'] = dict(
    lang='ja',
    intro='Party Stash と SadoQoL を一つにした MOD：新デザインのインベントリ画面にパーティ共有の無限収納箱、商人・学者・'
          'リッチのいる休息キャンプ、最大 32 人のパーティ、そして多数の快適性の向上。すべての機能は選択式のコンポーネントです。',
    h_components='コンポーネント', c_num='#', c_name='コンポーネント', experimental='実験的',
    h_compat='互換性', compat_head=('', 'BGEE', 'EET', 'BG2EE'),
    compat=[('Party Stash、整理された戦利品、オプション (#0-#7)', '対応', '対応', '対応'),
            ('休息キャンプとその住人 (#10-#15)', '対応', '対応', '今後対応'),
            ('快適性の向上 (#20-#32)', '対応', '対応', '対応'),
            ('大人数パーティ、7〜32 人 (#40)', '対応', '対応', '非対応')],
    compat_note='ゲームバージョン 2.6.6 と 2.7.3。すべてのコンポーネントに EEex が必要です。',
    h_install='インストール', install=[
        'EEex をインストールします。',
        'アーカイブをゲームフォルダ（chitin.key のある場所）に展開します。',
        'setup-SadoEE.exe を実行し、言語と必要なコンポーネントを選びます。',
        'InfinityLoader.exe (EEex) でゲームを起動します。'],
    h_upgrade='Party Stash や SadoQoL から移行する場合',
    upgrade='SadoEE は両方の MOD を置き換えます（同じファイル）：まず Party Stash と SadoQoL の全コンポーネントを'
            'アンインストールし、それから SadoEE をインストールしてください。セーブはそのまま使えます：収納箱の中身、'
            'キャンプとその住人の名前は変わりません。',
    h_uninstall='アンインストール',
    uninstall='まずゲーム内で収納箱を空にしてください：重量の横の大きな袋を Ctrl＋左クリック。そうしないと、中身はセーブに'
              '残りますが、収納箱を再インストールするまで取り出せません。大人数パーティの場合、#40 をアンインストールする前に'
              'パーティを 6 人以下に戻してください。',
    h_help='ゲーム内', help='インベントリ画面の金色の ? ボタンが収納箱画面の各部を説明します。キャンプへはワールドマップから：'
                            '「移動」ボタンの上の羊皮紙です。',
    h_license='ライセンス', license='MIT。作者：sad0。')

TEXT['korean'] = dict(
    lang='ko',
    intro='Party Stash와 SadoQoL을 하나로 합친 모드: 새로 디자인한 인벤토리 화면의 파티 공용 무한 보관함, 상인·학자·리치가 '
          '있는 휴식 야영지, 최대 32명의 파티, 그리고 다양한 편의성 개선. 모든 기능은 선택 가능한 구성 요소입니다.',
    h_components='구성 요소', c_num='#', c_name='구성 요소', experimental='실험적',
    h_compat='호환성', compat_head=('', 'BGEE', 'EET', 'BG2EE'),
    compat=[('Party Stash, 정렬된 전리품, 옵션 (#0-#7)', '예', '예', '예'),
            ('휴식 야영지와 주민 (#10-#15)', '예', '예', '아직 아님'),
            ('편의성 개선 (#20-#32)', '예', '예', '예'),
            ('대규모 파티, 7~32명 (#40)', '예', '예', '아니요')],
    compat_note='게임 버전 2.6.6 및 2.7.3. 모든 구성 요소에 EEex가 필요합니다.',
    h_install='설치', install=[
        'EEex를 설치합니다.',
        '압축 파일을 게임 폴더(chitin.key가 있는 곳)에 풉니다.',
        'setup-SadoEE.exe를 실행하고 언어와 원하는 구성 요소를 고릅니다.',
        'InfinityLoader.exe (EEex)로 게임을 시작합니다.'],
    h_upgrade='Party Stash 또는 SadoQoL에서 옮겨 오는 경우',
    upgrade='SadoEE는 두 모드를 대체합니다(같은 파일): 먼저 Party Stash와 SadoQoL의 모든 구성 요소를 제거한 뒤 SadoEE를 '
            '설치하세요. 저장 파일은 그대로 작동합니다: 보관함 내용, 야영지와 주민의 이름은 그대로 유지됩니다.',
    h_uninstall='제거',
    uninstall='먼저 게임에서 보관함을 비우세요: 무게 옆의 큰 가방을 Ctrl + 왼쪽 클릭. 그렇지 않으면 내용물은 저장 파일에 '
              '남지만 보관함을 다시 설치할 때까지 꺼낼 수 없습니다. 대규모 파티라면 #40을 제거하기 전에 파티를 6명 이하로 '
              '줄이세요.',
    h_help='게임 안에서', help='인벤토리 화면의 금색 ? 버튼이 보관함 화면의 각 부분을 설명합니다. 야영지는 세계 지도에서 '
                               '갑니다: 이동 버튼 위의 양피지.',
    h_license='라이선스', license='MIT. 제작자: sad0.')
