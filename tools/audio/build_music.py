"""Banco de música do RagnaEx: faixas CC0 do OpenGameArt (licença conferida na página de cada uma em 2026-11-10: só "CC0",
nenhuma com licença dupla). Baixa para .godot/music_cache, copia para assets/audio/music/<tema>.<ext> e escreve
assets/audio/music/CREDITS.md. Os temas são os de game/audio/music.gd (Music.MAP_THEME, "chefe", "investida").

    python tools/audio/build_music.py        (depois: godot --headless --path . --import)
"""
import os
import shutil
import urllib.parse
import urllib.request
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CACHE = os.path.join(ROOT, ".godot", "music_cache")
OUT = os.path.join(ROOT, "assets", "audio", "music")
FILES = "https://opengameart.org/sites/default/files/"

# tema -> (arquivo no OpenGameArt, dentro do zip ou "", título, autor, página)
TRACKS = {
    "aldara": ("TownTheme.mp3", "", "Town Theme RPG", "cynicmusic", "town-theme-rpg"),
    "taverna": ("The_Old_Tower_Inn.mp3", "", "Medieval: The Old Tower Inn", "RandomMind", "medieval-the-old-tower-inn"),
    "campo": ("the_field_of_dreams.mp3", "", "The Field Of Dreams", "pauliuw", "the-field-of-dreams"),
    "elfos": ("forest_2_0.ogg", "", "Cathedral in the forest (ambient loop)", "congusbongus", "cathedral-in-the-forest-ambient-loop"),
    "bastiao": ("A%20Legend%20Will%20Rise.mp3", "", "A Legend Will Rise (Orchestral)", "CodeManu", "a-legend-will-rise-orchestral"),
    "masmorra": ("dungeon002_0.ogg", "", "Dungeon Ambience", "yd", "dungeon-ambience"),
    "caverna": ("dark_cavern_ambient_001.ogg", "", "Dark Cavern Ambient", "Paul Wortmann", "dark-cavern-ambient"),
    "catacumbas": ("JRPG%20Music%20Pack%20%233%20%5BEvil%5D%20by%20Juhani%20Junkala.zip", "Evil2 - Catacombs.ogg", "Catacombs (JRPG Pack 3 Evil)", "Juhani Junkala (SubspaceAudio)", "jrpg-pack-3-evil"),
    "trevas": ("JRPG%20Music%20Pack%20%233%20%5BEvil%5D%20by%20Juhani%20Junkala.zip", "Evil1 - Ancient Evil Awakens.ogg", "Ancient Evil Awakens (JRPG Pack 3 Evil)", "Juhani Junkala (SubspaceAudio)", "jrpg-pack-3-evil"),
    "cidadela": ("JRPG%20Music%20Pack%20%233%20%5BEvil%5D%20by%20Juhani%20Junkala.zip", "Evil3 - Apocalypse.ogg", "Apocalypse (JRPG Pack 3 Evil)", "Juhani Junkala (SubspaceAudio)", "jrpg-pack-3-evil"),
    "chefe": ("bosstheme_WO_low_0.mp3", "", "Boss Fight", "Lisboa", "boss-fight-0"),
    "investida": ("battleThemeA.mp3", "", "Battle Theme A", "cynicmusic", "battle-theme-a"),
}


def fetch(name):
    os.makedirs(CACHE, exist_ok=True)
    local = os.path.join(CACHE, urllib.parse.unquote(name))
    if not os.path.exists(local):
        print("baixando", urllib.parse.unquote(name))
        with urllib.request.urlopen(FILES + name, timeout=120) as r, open(local, "wb") as f:
            f.write(r.read())
    return local


def main():
    os.makedirs(OUT, exist_ok=True)
    credits = ["# Música (todas CC0, OpenGameArt; licença conferida na página de cada faixa)", "",
               "| Tema | Faixa | Autor | Página |", "|---|---|---|---|"]
    for theme, (name, inner, title, author, page) in TRACKS.items():
        src = fetch(name)
        if inner:
            ext = os.path.splitext(inner)[1]
            dst = os.path.join(OUT, theme + ext)
            with zipfile.ZipFile(src) as z, z.open(inner) as i, open(dst, "wb") as o:
                shutil.copyfileobj(i, o)
        else:
            ext = os.path.splitext(urllib.parse.unquote(name))[1]
            dst = os.path.join(OUT, theme + ext)
            shutil.copyfile(src, dst)
        credits.append("| %s | %s | %s | https://opengameart.org/content/%s |" % (theme, title, author, page))
        print("%-10s -> %s (%.1f MB)" % (theme, os.path.basename(dst), os.path.getsize(dst) / 1048576))
    with open(os.path.join(OUT, "CREDITS.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(credits) + "\n")


if __name__ == "__main__":
    main()
