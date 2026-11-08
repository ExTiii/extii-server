const { ref, onBeforeUnmount } = Vue

const app = Vue.createApp({
  data: function() {
		return {
			isOutMapChecked: this.initIsOutMapChecked(),
      isOutCompassChecked: this.initIsOutCompassChecked(),
      isCompassFollowChecked: this.initIsCompassFollowChecked(),
      isMapNotifChecked: this.initIsMapNotifChecked(),
      isLowFuelChecked: this.initIsLowFuelChecked(),
      isCinematicNotifChecked: this.initIsCinematicNotifChecked(),
      isDynamicHealthChecked: this.initIsDynamicHealthChecked(),
      isDynamicArmorChecked: this.initIsDynamicArmorChecked(),
      isDynamicHungerChecked: this.initIsDynamicHungerChecked(),
      isDynamicThirstChecked: this.initIsDynamicThirstChecked(),
      isDynamicStressChecked: this.initIsDynamicStressChecked(),
      isDynamicOxygenChecked: this.initIsDynamicOxygenChecked(),
      isChangeFPSChecked: this.initIsChangeFPSChecked(),
      isToggleMapShapeChecked: this.initIsToggleMapShapeChecked(),
      isHideMapChecked: this.initIsHideMapChecked(),
      isToggleMapBordersChecked: this.initIsToggleMapBordersChecked(),
      isDynamicEngineChecked: this.initIsDynamicEngineChecked(),
      isDynamicNitroChecked: this.initIsDynamicNitroChecked(),
      isChangeCompassFPSChecked: this.initIsChangeCompassFPSChecked(),
      isShowCompassChecked: this.initIsShowCompassChecked(),
      isShowStreetsChecked: this.initIsShowStreetsChecked(),
      isPointerShowChecked: this.initIsPointerShowChecked(),
      isDegreesShowChecked: this.initIsDegreesShowChecked(),
      isCineamticModeChecked: this.initIsCineamticModeChecked(),
		};
	},
  setup () {
    const progress = ref([
      { loading: false, percentage: 0 },
      { loading: false, percentage: 0 },
      { loading: false, percentage: 0 }
    ])
    
    const intervals = [ null, null, null ]

    function startComputing (id) {
      progress.value[ id ].loading = true
      progress.value[ id ].percentage = 0

      intervals[ id ] = setInterval(() => {
        progress.value[ id ].percentage += Math.floor(Math.random() * 8 + 10)
        if (progress.value[ id ].percentage >= 100) {
          clearInterval(intervals[ id ])
          progress.value[ id ].loading = false
        }
      }, 700)
    }

    onBeforeUnmount(() => {
      intervals.forEach(val => {
        clearInterval(val)
      })
    }) 
    return {
      framework: {
        plugins: [
          'LocalStorage',
          'SessionStorage'
        ]
      },
      tab: ref('hud'),
      splitterModel: ref(20),
      selection: ref([]),
      progress,
      startComputing,
    }
  },
  watch: {
    isOutMapChecked: function() {
			localStorage.setItem("isOutMapChecked", this.isOutMapChecked);
		},
    isOutCompassChecked: function() {
			localStorage.setItem("isOutCompassChecked", this.isOutCompassChecked);
		},
    isCompassFollowChecked: function() {
			localStorage.setItem("isCompassFollowChecked", this.isCompassFollowChecked);
		},
    isMapNotifChecked: function() {
			localStorage.setItem("isMapNotifChecked", this.isMapNotifChecked);
		},
    isLowFuelChecked: function() {
			localStorage.setItem("isLowFuelChecked", this.isLowFuelChecked);
		},
    isCinematicNotifChecked: function() {
			localStorage.setItem("isCinematicNotifChecked", this.isCinematicNotifChecked);
		},
    isDynamicHealthChecked: function() {
			localStorage.setItem("isDynamicHealthChecked", this.isDynamicHealthChecked);
		},
    isDynamicArmorChecked: function() {
			localStorage.setItem("isDynamicArmorChecked", this.isDynamicArmorChecked);
		},
    isDynamicHungerChecked: function() {
			localStorage.setItem("isDynamicHungerChecked", this.isDynamicHungerChecked);
		},
    isDynamicThirstChecked: function() {
			localStorage.setItem("isDynamicThirstChecked", this.isDynamicThirstChecked);
		},
    isDynamicStressChecked: function() {
			localStorage.setItem("isDynamicStressChecked", this.isDynamicStressChecked);
		},
    isDynamicOxygenChecked: function() {
			localStorage.setItem("isDynamicOxygenChecked", this.isDynamicOxygenChecked);
		},
    isChangeFPSChecked: function() {
			localStorage.setItem("isChangeFPSChecked", this.isChangeFPSChecked);
		},
    isToggleMapShapeChecked: function() {
			localStorage.setItem("isToggleMapShapeChecked", this.isToggleMapShapeChecked);
		},
    isHideMapChecked: function() {
			localStorage.setItem("isHideMapChecked", this.isHideMapChecked);
		},
    isToggleMapBordersChecked: function() {
			localStorage.setItem("isToggleMapBordersChecked", this.isToggleMapBordersChecked);
		},
    isDynamicEngineChecked: function() {
			localStorage.setItem("isDynamicEngineChecked", this.isDynamicEngineChecked);
		},
    isDynamicNitroChecked: function() {
			localStorage.setItem("isDynamicNitroChecked", this.isDynamicNitroChecked);
		},
    isChangeCompassFPSChecked: function() {
			localStorage.setItem("isChangeCompassFPSChecked", this.isChangeCompassFPSChecked);
		},
    isShowCompassChecked: function() {
			localStorage.setItem("isShowCompassChecked", this.isShowCompassChecked);
		},
    isShowStreetsChecked: function() {
			localStorage.setItem("isShowStreetsChecked", this.isShowStreetsChecked);
		},
    isPointerShowChecked: function() {
			localStorage.setItem("isPointerShowChecked", this.isPointerShowChecked);
		},
    isDegreesShowChecked: function() {
			localStorage.setItem("isDegreesShowChecked", this.isDegreesShowChecked);
		},
    isCineamticModeChecked: function() {
			localStorage.setItem("isCineamticModeChecked", this.isCineamticModeChecked);
		},
	},
  methods: {
    initIsOutMapChecked: function() {
			const stored = localStorage.getItem("isOutMapChecked");
			if (stored === null) {
				return false; // server default: minimap also shows on foot
			} else {
				return stored == 'true';
			}
		},
    initIsOutCompassChecked: function() {
			const stored = localStorage.getItem("isOutCompassChecked");
			if (stored === null) {
				return true;
			} else {
				return stored == 'true';
			}
		},
    initIsCompassFollowChecked: function() {
			const stored = localStorage.getItem("isCompassFollowChecked");
			if (stored === null) {
				return true;
			} else {
				return stored == 'true';
			}
		},
    initIsMapNotifChecked: function() {
			const stored = localStorage.getItem("isMapNotifChecked");
			if (stored === null) {
				return true;
			} else {
				return stored == 'true';
			}
		},
    initIsLowFuelChecked: function() {
			const stored = localStorage.getItem("isLowFuelChecked");
			if (stored === null) {
				return true;
			} else {
				return stored == 'true';
			}
		},
    initIsCinematicNotifChecked: function() {
			const stored = localStorage.getItem("isCinematicNotifChecked");
			if (stored === null) {
				return true;
			} else {
				return stored == 'true';
			}
		},
    initIsDynamicHealthChecked: function() {
			const stored = localStorage.getItem("isDynamicHealthChecked");
			if (stored === null) {
				return false;
			} else {
				return stored == 'true';
			}
		},
    initIsDynamicArmorChecked: function() {
			const stored = localStorage.getItem("isDynamicArmorChecked");
			if (stored === null) {
				return false;
			} else {
				return stored == 'true';
			}
		},
    initIsDynamicHungerChecked: function() {
			const stored = localStorage.getItem("isDynamicHungerChecked");
			if (stored === null) {
				return false;
			} else {
				return stored == 'true';
			}
		},
    initIsDynamicThirstChecked: function() {
			const stored = localStorage.getItem("isDynamicThirstChecked");
			if (stored === null) {
				return false;
			} else {
				return stored == 'true';
			}
		},
    initIsDynamicStressChecked: function() {
			const stored = localStorage.getItem("isDynamicStressChecked");
			if (stored === null) {
				return false;
			} else {
				return stored == 'true';
			}
		},
    initIsDynamicOxygenChecked: function() {
			const stored = localStorage.getItem("isDynamicOxygenChecked");
			if (stored === null) {
				return false;
			} else {
				return stored == 'true';
			}
		},
    initIsChangeFPSChecked: function() {
			const stored = localStorage.getItem("isChangeFPSChecked");
			if (stored === null) {
				return 'Optimized';
			} else {
				return stored;
			}
		}, 
    initIsToggleMapShapeChecked: function() {
			const stored = localStorage.getItem("isToggleMapShapeChecked");
			if (stored === null) {
				return 'Circle';
			} else {
				return stored;
			}
		},
    initIsHideMapChecked: function() {
			const stored = localStorage.getItem("isHideMapChecked");
			if (stored === null) {
				return true;
			} else {
				return stored == 'true';
			}
		},
    initIsToggleMapBordersChecked: function() {
			const stored = localStorage.getItem("isToggleMapBordersChecked");
			if (stored === null) {
				return true;
			} else {
				return stored == 'true';
			}
		},
    initIsDynamicEngineChecked: function() {
			const stored = localStorage.getItem("isDynamicEngineChecked");
			if (stored === null) {
				return false;
			} else {
				return stored == 'true';
			}
		},
    initIsDynamicNitroChecked: function() {
			const stored = localStorage.getItem("isDynamicNitroChecked");
			if (stored === null) {
				return false;
			} else {
				return stored == 'true';
			}
		},
    initIsChangeCompassFPSChecked: function() {
			const stored = localStorage.getItem("isChangeCompassFPSChecked");
			if (stored === null) {
				return 'Optimized';
			} else {
				return stored;
			}
		}, 
    initIsShowCompassChecked: function() {
			const stored = localStorage.getItem("isShowCompassChecked");
			if (stored === null) {
				return true;
			} else {
				return stored == 'true';
			}
		},
    initIsShowStreetsChecked: function() {
			const stored = localStorage.getItem("isShowStreetsChecked");
			if (stored === null) {
				return true;
			} else {
				return stored == 'true';
			}
		},
    initIsPointerShowChecked: function() {
			const stored = localStorage.getItem("isPointerShowChecked");
			if (stored === null) {
				return true;
			} else {
				return stored == 'true';
			}
		},
    initIsDegreesShowChecked: function() {
			const stored = localStorage.getItem("isDegreesShowChecked");
			if (stored === null) {
				return true;
			} else {
				return stored == 'true';
			}
		},
    initIsCineamticModeChecked: function() {
			const stored = localStorage.getItem("isCineamticModeChecked");
			if (stored === null) {
				return false;
			} else {
				return stored == 'true';
			}
		},
    resetStorage: function(event) {
      targetId = event.currentTarget.id;
      localStorage.clear();
      resetStorage()
    },
    restartHud: function(event) {
      targetId = event.currentTarget.id;
      restartHud()
    },
    showOutMap: function(event) {
      targetId = event.currentTarget.id;
      showOutMap()
    },
    showOutCompass: function(event) {
      targetId = event.currentTarget.id;
      showOutCompass()
    },
    showFollowCompass: function(event) {
      targetId = event.currentTarget.id;
      showFollowCompass()
    },
    showMapNotif: function(event) {
      targetId = event.currentTarget.id;
      showMapNotif()
    },
    showFuelAlert: function(event) {
      targetId = event.currentTarget.id;
      showFuelAlert()
    },
    showCinematicNotif: function(event) {
      targetId = event.currentTarget.id;
      showCinematicNotif()
    },
    dynamicHealth: function(event) {
      targetId = event.currentTarget.id;
      dynamicHealth()
    },
    dynamicArmor: function(event) {
      targetId = event.currentTarget.id;
      dynamicArmor()
    },
    dynamicHunger: function(event) {
      targetId = event.currentTarget.id;
      dynamicHunger()
    },
    dynamicThirst: function(event) {
      targetId = event.currentTarget.id;
      dynamicThirst()
    },
    dynamicStress: function(event) {
      targetId = event.currentTarget.id;
      dynamicStress()
    },
    dynamicOxygen: function(event) {
      targetId = event.currentTarget.id;
      dynamicOxygen()
    },
    changeFPS: function(event) {
      targetId = event.currentTarget.id;
      changeFPS()
    },
    ToggleMapShape: function(event) {
      targetId = event.currentTarget.id;
      ToggleMapShape()
    },
    HideMap: function(event) {
      targetId = event.currentTarget.id;
      HideMap()
    },
    ToggleMapBorders: function(event) {
      targetId = event.currentTarget.id;
      ToggleMapBorders()
    },
    dynamicEngine: function(event) {
      targetId = event.currentTarget.id;
      dynamicEngine()
    },
    dynamicNitro: function(event) {
      targetId = event.currentTarget.id;
      dynamicNitro()
    },
    changeCompassFPS: function(event) {
      targetId = event.currentTarget.id;
      changeCompassFPS()
    },
    showCompassBase: function(event) {
      targetId = event.currentTarget.id;
      showCompassBase()
    },
    showStreetsNames: function(event) {
      targetId = event.currentTarget.id;
      showStreetsNames()
    },
    showPointerIndex: function(event) {
      targetId = event.currentTarget.id;
      showPointerIndex()
    },
    showDegreesNum: function(event) {
      targetId = event.currentTarget.id;
      showDegreesNum()
    },
    cinematicMode: function(event) {
      targetId = event.currentTarget.id;
      cinematicMode()
    },
  },
  mounted() {
    this.listener = window.addEventListener("message", (event) => {
        if (event.data.event === 'isToggleMapShapeChecked' || event.data.event === 'isChangeFPSChecked') {
          eval(`this.${event.data.event} = "${event.data.toggle}"`)
        }
    });
  },
})

app.use(Quasar, { config: {} })
app.mount('#menu')

document.onkeyup = function (data) {
  if (data.key == 'Escape') {
    closeMenu()
  }
};

function closeMenu() {
  $("#openmenu").fadeOut(550);
  $.post(`https://${GetParentResourceName()}/closeMenu`);
}
function restartHud() {
  closeMenu()
  $.post(`https://${GetParentResourceName()}/restartHud`);
}
function resetStorage() {
  closeMenu()
  $.post(`https://${GetParentResourceName()}/resetStorage`);
}
function showOutMap() {
  $.post(`https://${GetParentResourceName()}/showOutMap`);
}
function showOutCompass() {
  $.post(`https://${GetParentResourceName()}/showOutCompass`);
}
function showFollowCompass() {
  $.post(`https://${GetParentResourceName()}/showFollowCompass`);
}
function showMapNotif() {
  $.post(`https://${GetParentResourceName()}/showMapNotif`);
}
function showFuelAlert() {
  $.post(`https://${GetParentResourceName()}/showFuelAlert`);
}
function showCinematicNotif() {
  $.post(`https://${GetParentResourceName()}/showCinematicNotif`);
}
function dynamicHealth() {
  $.post(`https://${GetParentResourceName()}/dynamicHealth`);
}
function dynamicArmor() {
  $.post(`https://${GetParentResourceName()}/dynamicArmor`);
}
function dynamicHunger() {
  $.post(`https://${GetParentResourceName()}/dynamicHunger`);
}
function dynamicThirst() {
  $.post(`https://${GetParentResourceName()}/dynamicThirst`);
}
function dynamicStress() {
  $.post(`https://${GetParentResourceName()}/dynamicStress`);
}
function dynamicOxygen() {
  $.post(`https://${GetParentResourceName()}/dynamicOxygen`);
}
function dynamicEngine() {
  $.post(`https://${GetParentResourceName()}/dynamicEngine`);
}
function dynamicNitro() {
  $.post(`https://${GetParentResourceName()}/dynamicNitro`);
}
function ToggleMapShape() {
  $.post(`https://${GetParentResourceName()}/ToggleMapShape`);
}
function changeFPS() {
  $.post(`https://${GetParentResourceName()}/changeFPS`);
}
function ToggleMapBorders() {
  $.post(`https://${GetParentResourceName()}/ToggleMapBorders`);
}
function HideMap() {
  $.post(`https://${GetParentResourceName()}/HideMap`);
}
function changeCompassFPS() {
  $.post(`https://${GetParentResourceName()}/changeCompassFPS`);
}
function showCompassBase() {
  $.post(`https://${GetParentResourceName()}/showCompassBase`);
}
function showStreetsNames() {
  $.post(`https://${GetParentResourceName()}/showStreetsNames`);
}
function showPointerIndex() {
  $.post(`https://${GetParentResourceName()}/showPointerIndex`);
}
function showDegreesNum() {
  $.post(`https://${GetParentResourceName()}/showDegreesNum`);
}
function cinematicMode() {
  $.post(`https://${GetParentResourceName()}/cinematicMode`);
}

$(document).ready(function () {
  window.addEventListener("message", function (event) {
    switch (event.data.action) {
    case "open":
      Open(event.data);
      break;
    }
  });
});

Open = function (data) {
  $("#openmenu").fadeIn(150);
}
$('.closeMenu').click(() => {
  closeMenu()
});

// MONEY HUD

const moneyHud = Vue.createApp({
  data() {
    return {
      cash: 0,
      bank: 0,
      amount: 0,
      plus: false,
      minus: false,
      showCash: false,
      showBank: false,
      showUpdate: false,
      hudShown: true,
    };
  },
  destroyed() {
    window.removeEventListener("message", this.listener);
  },
  mounted() {
    this.listener = window.addEventListener("message", (event) => {
      switch (event.data.action) {
        case "showconstant":
          this.showConstant(event.data);
          break;
        case "updatemoney":
          this.update(event.data);
          break;
        case "show":
          this.showAccounts(event.data);
          break;
        // always-on money cards (sent every second by client/main.lua)
        case "money":
          this.cash = event.data.cash;
          this.bank = event.data.bank;
          this.showCash = true;
          this.showBank = true;
          break;
        // hide the money together with the rest of the HUD (pause menu etc.)
        case "hudtick":
          if (event.data.show !== undefined) this.hudShown = event.data.show !== false;
          break;
      }
    });
  },
  methods: {
    // CONFIGURE YOUR CURRENCY HERE
    // https://www.w3schools.com/tags/ref_language_codes.asp LANGUAGE CODES
    // https://www.w3schools.com/tags/ref_country_codes.asp COUNTRY CODES
    fmt(value) {
      return "$" + Math.round(Number(value) || 0).toLocaleString("en-US");
    },
    formatMoney(value) {
      const formatter = new Intl.NumberFormat("en-US", {
        style: "currency",
        currency: "USD",
        minimumFractionDigits: 0,
      });
      return formatter.format(value);
    },
    showConstant(data) {
      this.showCash = true;
      this.showBank = true;
      this.cash = data.cash;
      this.bank = data.bank;
    },
    update(data) {
      this.amount = data.amount;
      this.bank = data.bank;
      this.cash = data.cash;
      this.minus = data.minus;
      this.plus = !data.minus;
      this.showCash = true;
      this.showBank = true;
      this.showUpdate = true;
      clearTimeout(this.changeTimer);
      this.changeTimer = setTimeout(() => (this.showUpdate = false), 2500);
    },
    showAccounts(data) {
      if (data.type === "cash") {
        this.showCash = true;
        this.cash = data.cash;
      } else if (data.type === "bank") {
        this.showBank = true;
        this.bank = data.bank;
      }
    },
  },
}).mount("#money-container");

// PLAYER HUD

const playerHud = {
  data() {
    return {
      dynamicHealth: 0,
      dynamicHunger: 0,
      dynamicThirst: 0,
      dynamicStress: 0,
      dynamicOxygen: 0,
      dynamicEngine: 0,
      dynamicNitro: 0,
      nos: 0,
      static: 100,
      health: 0,
      playerDead: 0,
      armor: 0,
      hunger: 0,
      thirst: 0,
      stress: 0,
      voice: 0,
      radio: 0,
      harness: 0,
      nitroActive: 0,
      cruise: 0,
      parachute: 0,
      oxygen: 0,
      hp: 0,
      armed: 0,
      speed: 0,
      engine: 0,
      cinematic: 0,
      dev: 0,
      ammo: 0,
      ammoMax: 0,
      voiceLevel: 0,
      stamina: 100,
      underwater: false,
      show: false,
      talking: false,
      showVoice: true,
      showHealth: true,
      showArmor: true,
      showHunger: true,
      showThirst: true,
      showNos: true,
      showStress: false,
      showOxygen: false,
      showArmed: true,
      showEngine: false,
      showCruise: false,
      showHarness: false,
      showParachute: false,
      showDev: false,
      voiceIcon: "fas fa-microphone",
      talkingColor: "#FFFFFF",
      nosColor: "",
      engineColor: "",
      armorColor: "",
      hungerColor: "",
      healthColor: "",
      thirstColor: "",
      customIndicators: [],
    };
  },
  
  computed: {
    // Numbers shown inside the circles
    healthText() {
      return this.playerDead ? 0 : Math.max(0, Math.round(this.health || 0));
    },
    voiceText() {
      const names = { 1: "\u0647\u0645\u0633", 2: "\u0639\u0627\u062F\u064A", 3: "\u0635\u0631\u0627\u062E" };
      return names[this.voiceLevel] || "\u062E\u0627\u0635";
    },
    ammoPercent() {
      if (!this.ammoMax) return this.ammo > 0 ? 100 : 0;
      return Math.min(100, (this.ammo / this.ammoMax) * 100);
    },
    visibleCustomIndicators() {
      return this.customIndicators.filter((indicator) => indicator.alwaysShow || indicator.value > 0);
    },
    // Server design kit colours: grey when quiet, gold when talking, red on the radio
    voiceColor() {
      if (this.talking && this.radio) return "#ff5f5f";
      if (this.talking) return "#20c997";
      return "#f4f3ef";
    },
    // Rows that only show sometimes. They sit ABOVE the fixed rows,
    // so the fixed rows never move.
    extraRows() {
      const pct = (v) => Math.max(0, Math.min(100, Math.round(Number(v) || 0)));
      const list = [];
      for (const ind of this.visibleCustomIndicators) {
        const c = ind.color || "#20c997";
        list.push({ key: "custom-" + ind.id, icon: ind.icon, value: pct(ind.value), color: c, iconColor: c, track: "rgba(255,255,255,0.15)" });
      }
      if (this.underwater) list.push(this.bar("oxygen", "fas fa-lungs", this.oxygen, "#bdbdbd", "#f4f4f4", "rgba(189,189,189,0.3)"));
      return list;
    },
    // Fixed rows: always shown, always in the same place (no numbers, like the picture)
    bars() {
      return [
        this.bar("health", "fas fa-heart", this.playerDead ? 0 : this.health, "#f04b4b", "#ffc9c9", "rgba(240,75,75,0.3)"),
        this.bar("armor", "fas fa-shield-alt", this.armor, "#14b8a6", "#a7f3d0", "rgba(20,184,166,0.3)"),
        this.bar("hunger", "fas fa-utensils", this.hunger, "#f59e0b", "#fcd34d", "rgba(245,158,11,0.3)"),
        this.bar("thirst", "fas fa-tint", this.thirst, "#60a5fa", "#bfdbfe", "rgba(96,165,250,0.3)"),
        this.bar("stamina", "fas fa-running", this.stamina, "#d97cf5", "#f0c4fb", "rgba(217,124,245,0.3)"),
      ];
    },
    voiceTrack() {
      return "rgba(244,243,239,0.22)";
    },
  },
  beforeUnmount() {
    window.removeEventListener("message", this.listener);
  },
  mounted() {
    this.listener = (event) => {
      if (event.data.action === "hudtick") {
        this.hudTick(event.data);
      } else if (event.data.action === "addCustomIndicator") {
        this.addCustomIndicator(event.data.indicator);
      } else if (event.data.action === "updateCustomIndicator") {
        this.updateCustomIndicator(event.data.id, event.data.value, event.data.color);
      } else if (event.data.action === "removeCustomIndicator") {
        this.removeCustomIndicator(event.data.id);
      } else if (event.data.action === "setCustomIndicators") {
        this.customIndicators = Object.values(event.data.indicators);
      }
    };
    window.addEventListener("message", this.listener);
    $.post(`https://${GetParentResourceName()}/customIndicatorsReady`, JSON.stringify({}));
    Config = {};
  },
  methods: {
    num(value) {
      return Math.max(0, Math.round(Number(value) || 0));
    },
    bar(key, icon, value, color, iconColor, track) {
      const v = Math.max(0, Math.min(100, Math.round(Number(value) || 0)));
      return { key, icon, value: v, color, iconColor, track };
    },
    addCustomIndicator(indicator) {
      const index = this.customIndicators.findIndex((item) => item.id === indicator.id);
      if (index === -1) {
        this.customIndicators.push({ ...indicator });
      } else {
        this.customIndicators.splice(index, 1, { ...indicator });
      }
    },
    updateCustomIndicator(id, value, color) {
      const indicator = this.customIndicators.find((item) => item.id === id);
      if (!indicator) return;
      indicator.value = value;
      if (color !== undefined) indicator.color = color;
    },
    removeCustomIndicator(id) {
      this.customIndicators = this.customIndicators.filter((indicator) => indicator.id !== id);
    },
    hudTick(data) {
      // Some messages only switch the HUD on/off. Keep the last numbers instead of wiping them.
      if (data.health === undefined) {
        if (data.show !== undefined) this.show = data.show;
        return;
      }
      this.show = data.show;
      this.health = data.health;
      this.armor = data.armor;
      this.hunger = data.hunger;
      this.thirst = data.thirst;
      this.stress = data.stress;
      this.voice = data.voice;
      this.talking = data.talking;
      this.radio = data.radio;
      this.nos = data.nos;
      this.oxygen = data.oxygen;
      this.cruise = data.cruise;
      this.nitroActive = data.nitroActive;
      this.harness = data.harness;
      this.speed = data.speed;
      this.armed = data.armed;
      this.parachute = data.parachute;
      this.hp = data.hp*5;
      this.engine = data.engine;
      this.cinematic = data.cinematic;
      this.dev = data.dev;
      this.ammo = data.ammo || 0;
      this.ammoMax = data.ammoMax || 0;
      this.voiceLevel = data.voiceLevel || 0;
      if (data.stamina !== undefined) this.stamina = data.stamina;
      this.underwater = data.underwater === true;
      this.playerDead = data.playerDead;
      this.dynamicHealth = data.dynamicHealth;
      this.dynamicArmor = data.dynamicArmor;
      this.dynamicHunger = data.dynamicHunger;
      this.dynamicThirst = data.dynamicThirst;
      this.dynamicStress = data.dynamicStress;
      this.dynamicOxygen = data.dynamicOxygen;
      this.dynamicEngine = data.dynamicEngine;
      this.dynamicNitro = data.dynamicNitro;

      this.showHealth = true; // always visible
      if (data.playerDead === false) {
        this.healthColor = "#3FA554";
      } else {
        this.healthColor = "#ff0000";
        this.health = 100;
      }

      this.showArmor = true; // always visible, even with no armor

      if (data.armor <= 0) {
        this.armorColor = "#FF0000";
      } else {
        this.armorColor = "#326dbf";
      }

      this.showHunger = true; // always visible
      if (data.hunger >= 100) {
        this.hungerColor = "#dd6e14";
      } else if(data.hunger <= 30){
        this.hungerColor = "#ff0000";
      } else{
        this.hungerColor = "#dd6e14";
      }

      this.showThirst = true; // always visible
      if (data.thirst >= 100) {
        this.thirstColor = "#1a7cad";
      } else if(data.thirst <= 30){
        this.thirstColor = "#ff0000";
      } else{
        this.thirstColor = "#1a7cad";
      }

      this.showStress = false; // stress is turned off on this server

      if (data.dynamicOxygen == true) {
        if (data.oxygen >= 100) {
          this.showOxygen = false; }
          else{
            this.showOxygen = true;
          }
      } else if (data.dynamicOxygen == false){
        this.showOxygen = true;
      } 

      if (data.dynamicEngine == true) {
        if (data.engine >= 95) {
          this.showEngine = false; 
        } else if  (data.engine < 0){
          this.showEngine = false;} else {this.showEngine = true;}
      } else if (data.dynamicEngine == false){
        if  (data.engine < 0) {
          this.showEngine = false;} else {this.showEngine = true;}
      } 
      if (data.engine <= 45) {
        this.engineColor = "#ff0000";
      } else if (data.engine <= 75 && data.engine >= 46 ) {
        this.engineColor = "#dd6e14";
      } else if(data.engine<=100) {
        this.engineColor = "#3FA554";
      } 

      if (data.dynamicNitro == true) {
      if (data.nos === 0 || data.nos === undefined) {
        this.showNos = false;
      } else if  (data.nos < 0){
        this.showNos = false;} else {this.showNos = true;}  
      } else if  (data.dynamicNitro == false)  {
        if  (data.nos < 0){
          this.showNos = false;
      } else {this.showNos = true;}
      }
      if (data.nitroActive) {
        this.nosColor = "#D64763";
      } else {
        this.nosColor = "#FFFFFF";
      }

      if (data.talking && data.radio) {
        this.talkingColor = "#D64763";
      } else if (data.talking) {
        this.talkingColor = '#FFFF3E';
      } else {
        this.talkingColor = "#FFFFFF";
      }
      if (data.radio != 0 && data.radio != undefined) {
        this.voiceIcon = 'fas fa-headset';
      } else if (data.radio == 0 || data.radio == undefined) {
        this.voiceIcon = 'fas fa-microphone';
      }
      if (data.cruise === true) {
        this.cruise = 1;
        this.showCruise = true;
      } else {
        this.cruise = 0;
        this.showCruise = false;
      }

      if (data.harness === true) {
        this.showHarness = true;
      } else {
        this.showHarness = false;
      }
      if (data.armed === true) {
        this.showArmed = true;
      } else {
        this.showArmed = false;
      }

      if (data.parachute >= 0 ) {
        this.showParachute = true;
      } else {
        this.showParachute = false;
      }

      if (data.dev === true ) {
        this.showDev = true;
      } else {
        this.showDev = false;
      }

      if (data.isPaused === 1) {
        this.show = false;
      }
    },
  },
};
const app2 = Vue.createApp(playerHud);
app2.use(Quasar);
app2.mount("#ui-container");

// VEHICLE HUD

const vehHud = {
  data() {
    return {
      speedometer: 66,
      fuelgauge: 69,
      altitudegauge: 75,
      fuel: 0,
      speed: 0,
      seatbelt: 0,
      altitude: 0,
      fuelPct: 0,
      engine: 100,
      gear: "N",
      maxSpeed: 200,
      odometer: 0,
      nos: 0,
      nitroActive: false,
      cruise: false,
      harness: false,
      showSquareB: 0,
      show: false,
      showAltitude: true,
      showSeatbelt: true,
      showSquare: false,
      showCircle: false,
      seatbeltColor: "",
    };
  },
  
  destroyed() {
    window.removeEventListener("message", this.listener);
  },
  mounted() {
    this.listener = window.addEventListener("message", (event) => {
      if (event.data.action === "car") {
        this.vehicleHud(event.data);
      } else if (event.data.action === "vehextra") {
        const d = event.data;
        if (typeof d.speed === "number") this.speed = d.speed;
        this.gear = d.gear || "N";
        if (typeof d.maxSpeed === "number" && d.maxSpeed > 0) this.maxSpeed = d.maxSpeed;
        if (typeof d.odometer === "number") this.odometer = d.odometer;
      } else if (event.data.action === "hudtick" && event.data.health !== undefined) {
        const d = event.data;
        this.engine = Math.max(0, Math.min(100, Math.round(Number(d.engine) || 0)));
        this.nos = Math.max(0, Math.min(100, Math.round(Number(d.nos) || 0)));
        this.nitroActive = d.nitroActive === true;
        this.cruise = d.cruise === true;
        this.harness = d.harness === true;
      }
    });
  },
  methods: {
    vehicleHud(data) {
      this.show = data.show;
      this.speed = data.speed;
      this.altitude = data.altitude;
      this.fuel = (data.fuel * 0.71);
      this.fuelPct = Math.max(0, Math.min(100, Math.round(Number(data.fuel) || 0)));
      this.showSeatbelt = data.showSeatbelt;
      this.showAltitude = data.showAltitude;
      this.showSquareB = data.showSquareB;
      this.showCircleB = data.showCircleB;
      if (data.seatbelt === true) {
        this.seatbelt = 1;
        this.seatbeltColor = "transparent";
      } else {
        this.seatbelt = 0;
        this.seatbeltColor = "#FF5100";
      }
      if (data.showSeatbelt === true) {
        this.showSeatbelt = true;
      } else {
        this.showSeatbelt = false;
      }
      if (data.showAltitude === true) {
        this.showAltitude = true;
      } else {
        this.showAltitude = false;
      }
      if (data.fuel <= 20) {
        this.fuelColor = "#ff0000";
      } else if (data.fuel <= 30) {
        this.fuelColor = "#dd6e14";
      } else {
        this.fuelColor = "#FFFFFF";
      }
      if (data.showSquareB === true) {
        this.showSquare = true;
      } else {
        this.showSquare = false;
      }
      if (data.showCircleB === true) {
        this.showCircle = true;
      } else {
        this.showCircle = false;
      }
      if (data.isPaused === 1) {
        this.show = false;
      }
    },
  },
};
vehHud.computed = {
  engineColor() {
    if (this.engine <= 45) return "#ff5f5f";
    if (this.engine <= 75) return "#f5b82e";
    return "#f4f3ef";
  },
  fuelKitColor() {
    if (this.fuelPct <= 20) return "#ff5f5f";
    if (this.fuelPct <= 30) return "#f5b82e";
    return "#f4f3ef";
  },
  speedPct() {
    return Math.max(0, Math.min(1, (Number(this.speed) || 0) / (this.maxSpeed || 200)));
  },
  odoText() {
    return String(Math.max(0, Math.min(999999, Math.floor(this.odometer || 0)))).padStart(6, "0");
  },
};
// ring helpers: 270 degree arcs drawn with stroke-dasharray
vehHud.methods.bigArc = function (fraction) {
  const c = 2 * Math.PI * 44;
  return { strokeDasharray: `${0.75 * c * fraction} ${c}` };
};
vehHud.methods.smallArc = function (value, color) {
  const c = 2 * Math.PI * 40;
  const f = Math.max(0, Math.min(1, (Number(value) || 0) / 100));
  return { strokeDasharray: `${0.75 * c * f} ${c}`, stroke: color };
};
const app3 = Vue.createApp(vehHud);
app3.use(Quasar);
app3.mount("#veh-container");

// COMPASS HUD

const baseplateHud = {
  data() {
    return {
      show: false,
      street1: "",
      street2: "",
      showCompass: true,
      showStreets: true,
      showPointer: true,
      showDegrees: true,
    };
  },
  destroyed() {
    window.removeEventListener("message", this.listener);
  },
  mounted() {
    this.listener = window.addEventListener("message", (event) => {
      if (event.data.action == "update") {
        type = event.data.type
        value = event.data.value
          if (value  !== undefined) {
            $('.degrees').html(value);
            bar = document.getElementsByTagName("svg")[0];
            bar.setAttribute("viewBox", ''+ (value - 90) + ' 0 180 5');
            heading = document.getElementsByTagName("svg")[1];
            heading.setAttribute("viewBox", ''+ (value - 90) + ' 0 180 1.5');
          }
        }
      if (event.data.action === "baseplate") {
        this.baseplateHud(event.data);
      }
    });
  },
  methods: {
    baseplateHud(data) {
      this.show = data.show;
      this.street1 = data.street1;
      this.street2 = data.street2;
      this.showCompass = data.showCompass;
      this.showStreets = data.showStreets;
      this.showPointer = data.showPointer;
      this.showDegrees = data.showDegrees;
      if (data.showCompass == true) {
        this.showCompass = true;
      } else {
        this.showCompass = false;
      }
      if (data.showStreets == true) {
        this.showStreets = true;
      } else {
        this.showStreets = false;
      }
      if (data.showPointer == true) {
        this.showPointer = true;
      } else {
        this.showPointer = false;
      }
      if (data.showDegrees == true) {
        this.showDegrees = true;
      } else {
        this.showDegrees = false;
      }
    },
  },
};
const app4 = Vue.createApp(baseplateHud);
app4.use(Quasar);
app4.mount("#baseplate-container");
