/mob/living/carbon/monkey
	name = "monkey"
	verb_say = "chimpers"
	initial_language_holder = /datum/language_holder/monkey
	possible_a_intents = list(INTENT_HELP, INTENT_DISARM, INTENT_HARM)
	icon = 'icons/mob/monkey.dmi'
	icon_state = null
	gender = NEUTER
	pass_flags = PASSTABLE
	ventcrawler = VENTCRAWLER_NUDE
	mob_biotypes = list(MOB_ORGANIC, MOB_HUMANOID)
	butcher_results = list(/obj/item/reagent_containers/food/snacks/meat/slab/monkey = 5, /obj/item/stack/sheet/animalhide/monkey = 1)
	type_of_meat = /obj/item/reagent_containers/food/snacks/meat/slab/monkey
	gib_type = /obj/effect/decal/cleanable/blood/gibs
	unique_name = TRUE
	blocks_emissive = EMISSIVE_BLOCK_UNIQUE
	bodyparts = list(/obj/item/bodypart/chest/monkey, /obj/item/bodypart/head/monkey, /obj/item/bodypart/l_arm/monkey,
					/obj/item/bodypart/r_arm/monkey, /obj/item/bodypart/r_leg/monkey, /obj/item/bodypart/l_leg/monkey)
	hud_type = /datum/hud/monkey
	mobchatspan = "monkeyhive"
	ai_controller = /datum/ai_controller/monkey
	faction = list("neutral", "monkey")

GLOBAL_LIST_INIT(strippable_monkey_items, create_strippable_list(list(
	/datum/strippable_item/hand/left,
	/datum/strippable_item/hand/right,
	/datum/strippable_item/mob_item_slot/handcuffs,
	/datum/strippable_item/mob_item_slot/legcuffs,
	/datum/strippable_item/mob_item_slot/head,
	/datum/strippable_item/mob_item_slot/back,
	/datum/strippable_item/mob_item_slot/mask,
	/datum/strippable_item/mob_item_slot/neck
)))

/mob/living/carbon/monkey/Initialize(mapload, cubespawned=FALSE, mob/spawner)
	add_verb(/mob/living/proc/mob_sleep)
	add_verb(/mob/living/proc/lay_down)

	if(unique_name) //used to exclude pun pun
		gender = pick(MALE, FEMALE)
	real_name = name

	//initialize limbs
	create_bodyparts()
	create_internal_organs()

	. = ..()

	if (cubespawned)
		var/cap = CONFIG_GET(number/max_cube_monkeys)
		if (LAZYLEN(SSmobs.cubemonkeys) > cap)
			if (spawner)
				to_chat(spawner, "<span class='warning'>Bluespace harmonics prevent the spawning of more than [cap] monkeys on the station at one time!</span>")
			return INITIALIZE_HINT_QDEL
		SSmobs.cubemonkeys += src

	create_dna()
	dna.initialize_dna(random_blood_type())
	AddElement(/datum/element/strippable, GLOB.strippable_monkey_items)

/mob/living/carbon/monkey/Destroy()
	SSmobs.cubemonkeys -= src
	return ..()

/mob/living/carbon/monkey/create_internal_organs()
	internal_organs += new /obj/item/organ/appendix
	internal_organs += new /obj/item/organ/lungs
	internal_organs += new /obj/item/organ/heart
	internal_organs += new /obj/item/organ/brain
	internal_organs += new /obj/item/organ/tongue
	internal_organs += new /obj/item/organ/eyes
	internal_organs += new /obj/item/organ/ears
	internal_organs += new /obj/item/organ/liver
	internal_organs += new /obj/item/organ/stomach
	..()

/mob/living/carbon/monkey/on_reagent_change()
	. = ..()
	remove_movespeed_modifier(MOVESPEED_ID_MONKEY_REAGENT_SPEEDMOD, TRUE)
	var/amount
	if(reagents.has_reagent(/datum/reagent/medicine/morphine))
		amount = -1
	if(reagents.has_reagent(/datum/reagent/consumable/nuka_cola))
		amount = -1
	if(amount)
		add_movespeed_modifier(MOVESPEED_ID_MONKEY_REAGENT_SPEEDMOD, TRUE, 100, override = TRUE, multiplicative_slowdown = amount)

/mob/living/carbon/monkey/updatehealth()
	. = ..()
	var/slow = 0
	if(!HAS_TRAIT(src, TRAIT_IGNOREDAMAGESLOWDOWN))
		var/health_deficiency = (maxHealth - health)
		if(health_deficiency >= 45)
			slow += (health_deficiency / 25)
	add_movespeed_modifier(MOVESPEED_ID_MONKEY_HEALTH_SPEEDMOD, TRUE, 100, override = TRUE, multiplicative_slowdown = slow)

/mob/living/carbon/monkey/get_stat_tab_status()
	var/list/tab_data = ..()
	if(client && mind)
		var/datum/antagonist/changeling/changeling = mind.has_antag_datum(/datum/antagonist/changeling)
		if(changeling)
			tab_data["Chemical Storage"] = GENERATE_STAT_TEXT("[changeling.chem_charges]/[changeling.chem_storage]")
			tab_data["Absorbed DNA"] = GENERATE_STAT_TEXT("[changeling.absorbedcount]")
	return tab_data


/mob/living/carbon/monkey/verb/removeinternal()
	set name = "Remove Internals"
	set category = "IC"
	internal = null
	return

/mob/living/carbon/monkey/reagent_check(datum/reagent/R) //can metabolize all reagents
	return FALSE

/mob/living/carbon/monkey/canBeHandcuffed()
	return TRUE

/mob/living/carbon/monkey/assess_threat(judgment_criteria, lasercolor = "", datum/callback/weaponcheck=null)
	if(judgment_criteria & JUDGE_EMAGGED)
		return 10 //Everyone is a criminal!

	var/threatcount = 0

	//Securitrons can't identify monkeys
	if( !(judgment_criteria & JUDGE_IGNOREMONKEYS) && (judgment_criteria & JUDGE_IDCHECK) )
		threatcount += 4

	//Lasertag bullshit
	if(lasercolor)
		if(lasercolor == "b")//Lasertag turrets target the opposing team, how great is that? -Sieve
			if(is_holding_item_of_type(/obj/item/gun/energy/laser/redtag))
				threatcount += 4

		if(lasercolor == "r")
			if(is_holding_item_of_type(/obj/item/gun/energy/laser/bluetag))
				threatcount += 4

		return threatcount

	//Check for weapons
	if( (judgment_criteria & JUDGE_WEAPONCHECK) && weaponcheck )
		for(var/obj/item/I in held_items) //if they're holding a gun
			if(weaponcheck.Invoke(I))
				threatcount += 4
		if(weaponcheck.Invoke(back)) //if a weapon is present in the back slot
			threatcount += 4 //trigger look_for_perp() since they're nonhuman and very likely hostile

	//mindshield implants imply trustworthyness
	if(has_mindshield_hud_icon())
		threatcount -= 1

	return threatcount

/mob/living/carbon/monkey/get_permeability_protection()
	var/protection = 0
	if(head)
		protection = 1 - head.permeability_coefficient
	if(wear_mask)
		protection = max(1 - wear_mask.permeability_coefficient, protection)
	protection = protection/7 //the rest of the body isn't covered.
	return protection

/mob/living/carbon/monkey/IsVocal()
	if(!getorganslot(ORGAN_SLOT_LUNGS))
		return 0
	return 1

/mob/living/carbon/monkey/can_use_guns(obj/item/G)
	return TRUE

/mob/living/carbon/monkey/angry
	ai_controller = /datum/ai_controller/monkey/angry

/mob/living/carbon/monkey/angry/Initialize(mapload)
	. = ..()
	if(prob(10))
		var/obj/item/clothing/head/helmet/justice/escape/helmet = new(src)
		equip_to_slot_or_del(helmet,ITEM_SLOT_HEAD)
		helmet.attack_self(src) // todo encapsulate toggle


//Special monkeycube subtype to track the number of them and prevent spam
/mob/living/carbon/monkey/cube/Initialize(mapload)
	. = ..()
	GLOB.total_cube_monkeys++

/mob/living/carbon/monkey/cube/death(gibbed)
	GLOB.total_cube_monkeys--
	..()

//In case admins delete them before they die
/mob/living/carbon/monkey/cube/Destroy()
	if(stat != DEAD)
		GLOB.total_cube_monkeys--
	return ..()

/mob/living/carbon/monkey/tumor
	name = "living teratoma"
	verb_say = "blabbers"
	initial_language_holder = /datum/language_holder/monkey
	icon = 'icons/mob/monkey.dmi'
	icon_state = null
	butcher_results = list(/obj/effect/spawner/lootdrop/teratoma/minor = 5, /obj/effect/spawner/lootdrop/teratoma/major = 1)
	type_of_meat = /obj/effect/spawner/lootdrop/teratoma/minor
	bodyparts = list(/obj/item/bodypart/chest/monkey/teratoma, /obj/item/bodypart/head/monkey/teratoma, /obj/item/bodypart/l_arm/monkey/teratoma,
					/obj/item/bodypart/r_arm/monkey/teratoma, /obj/item/bodypart/r_leg/monkey/teratoma, /obj/item/bodypart/l_leg/monkey/teratoma)
	ai_controller = null

/datum/dna/tumor
	species = new /datum/species/teratoma

/datum/species/teratoma
	name = "Teratoma"
	id = "teratoma"
	species_traits = list(NOTRANSSTING, NO_DNA_COPY, EYECOLOR, HAIR, FACEHAIR, LIPS)
	inherent_traits = list(TRAIT_NOHUNGER, TRAIT_RADIMMUNE, TRAIT_BADDNA, TRAIT_NOGUNS, TRAIT_NONECRODISEASE)	//Made of mutated cells
	default_features = list("mcolor" = "FFF", "wings" = "None")
	use_skintones = FALSE
	skinned_type = /obj/item/stack/sheet/animalhide/monkey
	liked_food = JUNKFOOD | FRIED | GROSS | RAW
	changesource_flags = MIRROR_BADMIN
	mutant_brain = /obj/item/organ/brain/tumor
	mutanttongue = /obj/item/organ/tongue/teratoma

	species_chest = /obj/item/bodypart/chest/monkey/teratoma
	species_head = /obj/item/bodypart/head/monkey/teratoma
	species_l_arm = /obj/item/bodypart/l_arm/monkey/teratoma
	species_r_arm = /obj/item/bodypart/r_arm/monkey/teratoma
	species_l_leg = /obj/item/bodypart/l_leg/monkey/teratoma
	species_r_leg = /obj/item/bodypart/r_leg/monkey/teratoma

/obj/item/organ/brain/tumor
	name = "teratoma brain"

/obj/item/organ/brain/tumor/Remove(mob/living/carbon/C, special, no_id_transfer)
	. = ..()
	//Removing it deletes it
	if(!QDELETED(src))
		qdel(src)

/mob/living/carbon/monkey/tumor/handle_mutations_and_radiation()
	return

/mob/living/carbon/monkey/tumor/has_dna()
	return FALSE

/mob/living/carbon/monkey/tumor/create_dna()
	dna = new /datum/dna/tumor(src)
	//Give us the juicy mutant organs
	dna.species.on_species_gain(src, null, FALSE)
	dna.species.regenerate_organs(src, replace_current = TRUE)
