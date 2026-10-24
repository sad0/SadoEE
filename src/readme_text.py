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
            ('Rest camp and its people (#10-#14)', 'yes', 'yes', 'not yet'),
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
            ('Camp de repos et ses habitants (#10-#14)', 'oui', 'oui', 'pas encore'),
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
