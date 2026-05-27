class_name PlanetData

# max_slots: 행성에 동시에 파견할 수 있는 최대 머신 수 (행성 고유 슬롯)
const LIST: Array = [
	{"id": "sector_a",  "name": "섹터 A",  "unlock_cost": 0,              "max_on_screen": 20,  "wave_size": 50,   "credit_per_kill": 10,    "enemy_hp": 2,    "max_slots": 1},
	{"id": "sector_b",  "name": "섹터 B",  "unlock_cost": 50,             "max_on_screen": 30,  "wave_size": 80,   "credit_per_kill": 15,    "enemy_hp": 3,    "max_slots": 1},
	{"id": "sector_c",  "name": "섹터 C",  "unlock_cost": 200,            "max_on_screen": 40,  "wave_size": 120,  "credit_per_kill": 25,    "enemy_hp": 5,    "max_slots": 1},
	{"id": "sector_d",  "name": "섹터 D",  "unlock_cost": 800,            "max_on_screen": 40,  "wave_size": 160,  "credit_per_kill": 40,    "enemy_hp": 8,    "max_slots": 1},
	{"id": "sector_e",  "name": "섹터 E",  "unlock_cost": 3000,           "max_on_screen": 50,  "wave_size": 200,  "credit_per_kill": 60,    "enemy_hp": 12,   "max_slots": 2},
	{"id": "sector_f",  "name": "섹터 F",  "unlock_cost": 10000,          "max_on_screen": 50,  "wave_size": 250,  "credit_per_kill": 90,    "enemy_hp": 18,   "max_slots": 2},
	{"id": "sector_g",  "name": "섹터 G",  "unlock_cost": 35000,          "max_on_screen": 60,  "wave_size": 300,  "credit_per_kill": 140,   "enemy_hp": 28,   "max_slots": 2},
	{"id": "sector_h",  "name": "섹터 H",  "unlock_cost": 120000,         "max_on_screen": 60,  "wave_size": 380,  "credit_per_kill": 200,   "enemy_hp": 40,   "max_slots": 2},
	{"id": "sector_i",  "name": "섹터 I",  "unlock_cost": 400000,         "max_on_screen": 70,  "wave_size": 480,  "credit_per_kill": 300,   "enemy_hp": 60,   "max_slots": 3},
	{"id": "sector_j",  "name": "섹터 J",  "unlock_cost": 1400000,        "max_on_screen": 70,  "wave_size": 600,  "credit_per_kill": 450,   "enemy_hp": 90,   "max_slots": 3},
	{"id": "sector_k",  "name": "섹터 K",  "unlock_cost": 5000000,        "max_on_screen": 80,  "wave_size": 750,  "credit_per_kill": 680,   "enemy_hp": 135,  "max_slots": 3},
	{"id": "sector_l",  "name": "섹터 L",  "unlock_cost": 18000000,       "max_on_screen": 80,  "wave_size": 950,  "credit_per_kill": 1000,  "enemy_hp": 200,  "max_slots": 3},
	{"id": "sector_m",  "name": "섹터 M",  "unlock_cost": 65000000,       "max_on_screen": 90,  "wave_size": 1200, "credit_per_kill": 1500,  "enemy_hp": 300,  "max_slots": 4},
	{"id": "sector_n",  "name": "섹터 N",  "unlock_cost": 230000000,      "max_on_screen": 90,  "wave_size": 1500, "credit_per_kill": 2200,  "enemy_hp": 450,  "max_slots": 4},
	{"id": "sector_o",  "name": "섹터 O",  "unlock_cost": 800000000,      "max_on_screen": 100, "wave_size": 1900, "credit_per_kill": 3300,  "enemy_hp": 680,  "max_slots": 4},
	{"id": "sector_p",  "name": "섹터 P",  "unlock_cost": 3000000000,     "max_on_screen": 100, "wave_size": 2400, "credit_per_kill": 5000,  "enemy_hp": 1000, "max_slots": 4},
	{"id": "sector_q",  "name": "섹터 Q",  "unlock_cost": 10000000000,    "max_on_screen": 100, "wave_size": 3000, "credit_per_kill": 7500,  "enemy_hp": 1500, "max_slots": 4},
	{"id": "sector_r",  "name": "섹터 R",  "unlock_cost": 35000000000,    "max_on_screen": 100, "wave_size": 3800, "credit_per_kill": 11000, "enemy_hp": 2200, "max_slots": 4},
	{"id": "sector_s",  "name": "섹터 S",  "unlock_cost": 120000000000,   "max_on_screen": 100, "wave_size": 4800, "credit_per_kill": 16000, "enemy_hp": 3300, "max_slots": 4},
	{"id": "sector_t",  "name": "섹터 T",  "unlock_cost": 400000000000,   "max_on_screen": 100, "wave_size": 6000, "credit_per_kill": 24000, "enemy_hp": 5000, "max_slots": 4},
]
