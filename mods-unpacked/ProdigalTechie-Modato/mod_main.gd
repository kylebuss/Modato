extends Node

const MOD_ID = "ProdigalTechie-Modato"
const MOD_DIR = MOD_ID + "/"

const EXTS = [
	"main.gd",
]

const SINGLETONS = [
	"item_service.gd"
]

const TRANS = [
	"translations.de.translation",
	"translations.en.translation",
	"translations.es.translation",
	"translations.fr.translation",
	"translations.it.translation",
	"translations.ja.translation",
	"translations.ko.translation",
	"translations.pl.translation",
	"translations.pt.translation",
	"translations.ru.translation",
	"translations.tr.translation",
	"translations.zh_Hans_CN.translation",
]

func _init():
	var dir = ModLoaderMod.get_unpacked_dir() + MOD_DIR
	var ext_dir = dir + "extensions/"
	var res_dir = dir + "translations/"
	# var sin_dir = dir + "singletons/"
	ModLoaderLog.info("installing script extensions", MOD_ID + ":Main")
	for ext_path in EXTS:
		ModLoaderMod.install_script_extension(ext_dir + ext_path)
	ModLoaderLog.info("installing script singletons", MOD_ID + ":Main")
	# for singleton in SINGLETONS:
	# 	ModLoaderMod.install_script_extension(sin_dir + singleton)
	# ModLoaderLog.info("installing translations", MOD_ID + ":Main")
	for tr_path in TRANS:
		ModLoaderMod.add_translation(res_dir + tr_path)

func _ready():
	ModLoaderLog.info("ready", MOD_ID + ":Main")
