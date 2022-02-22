var/global/list/obj/machinery/faxmachine/allfaxes = list()
var/global/list/alldepartments = list("Central Command")

/obj/machinery/faxmachine
	name = "fax machine"
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "fax"
	req_one_access = list(access_lawyer, access_heads)
	anchored = TRUE
	density = TRUE
	use_power = IDLE_POWER_USE
	idle_power_usage = 30
	active_power_usage = 200
	interact_offline = TRUE
	allowed_checks = ALLOWED_CHECK_NONE
	var/obj/item/weapon/card/id/scan = null // identification
	var/authenticated = 0

	var/obj/item/weapon/paper/tofax = null // what we're sending
	var/sendcooldown = 0 // to avoid spamming fax messages

	var/department = "Unknown" // our department
	var/dptdest = "Central Command" // the department we're sending to

/obj/machinery/faxmachine/atom_init()
	. = ..()
	allfaxes += src

	if( !("[department]" in alldepartments) )
		alldepartments += department

/obj/machinery/faxmachine/Destroy()
	allfaxes -= src
	QDEL_NULL(scan)
	QDEL_NULL(tofax)
	return ..()

/obj/machinery/faxmachine/ui_interact(mob/user)
	var/dat

	var/scan_name
	if(scan)
		scan_name = scan.name
	else
		scan_name = "--------"

	dat += "Подтвердить личность: <a href='byond://?src=\ref[src];scan=1'>[scan_name]</a><br>"

	if(authenticated)
		dat += "<a href='byond://?src=\ref[src];logout=1'>Выйти</a>"
	else
		dat += "<a href='byond://?src=\ref[src];auth=1'>Войти</a>"

	dat += "<hr>"

	if(authenticated)
		dat += "<b>Соединено с:</b> Квантовая Сеть Коммуникации ЦК<br><br>"

		if(tofax)
			dat += "<a href='byond://?src=\ref[src];remove=1'>Извлечь лист</a><br><br>"

			if(sendcooldown)
				dat += "<b>Производится калибровка передатчиков. Ожидайте.</b><br>"

			else
				dat += "<a href='byond://?src=\ref[src];send=1'>Отправить</a><br>"
				dat += "<b>Документ внутри:</b> [tofax.name]<br>"
				dat += "<b>Получатель:</b> <a href='byond://?src=\ref[src];dept=1'>[dptdest]</a><br>"

		else
			if(sendcooldown)
				dat += "Вставьте лист для отправки сообщения по зашифрованному каналу.<br><br>"
				dat += "<b>Производится калибровка передатчиков. Ожидайте.</b><br>"
			else
				dat += "Вставьте лист для отправки сообщения по зашифрованному каналу.<br><br>"

	else
		dat += "Для использования необходима авторизация.<br><br>"

		if(tofax)
			dat += "<a href ='byond://?src=\ref[src];remove=1'>Извлечь лист</a><br>"

	var/datum/browser/popup = new(user, "window=copier", "Fax Machine", 450, 300)
	popup.set_content(dat)
	popup.open()

/obj/machinery/faxmachine/is_operational()
	return TRUE

/obj/machinery/faxmachine/Topic(href, href_list)
	. = ..()
	if(!.)
		return

	if(href_list["send"])
		if(sendcooldown)
			return

		if(tofax)
			if(dptdest == "Central Command")
				sendcooldown = 1800
				centcomm_fax(usr, tofax, src)
			else
				sendcooldown = 600
				send_fax(usr, tofax, dptdest)

			audible_message("Сообщение отправлено успешно.")

			spawn(sendcooldown) // cooldown time
				sendcooldown = 0

	if(href_list["remove"])
		if(tofax)
			if(!ishuman(usr))
				to_chat(usr, "<span class='warning'>Вы не можете этого сделать.</span>")
			else
				tofax.loc = usr.loc
				usr.put_in_hands(tofax)
				to_chat(usr, "<span class='notice'>You take the paper out of \the [src].</span>")
				tofax = null

	if(href_list["scan"])
		if (scan)
			if(ishuman(usr))
				scan.loc = usr.loc
				if(!usr.get_active_hand())
					usr.put_in_hands(scan)
				scan = null
			else
				scan.loc = src.loc
				scan = null
		else if(ishuman (usr))
			var/obj/item/I = usr.get_active_hand()
			if (istype(I, /obj/item/weapon/card/id))
				usr.drop_from_inventory(I, src)
				scan = I
		if(ishuman(usr))
			var/mob/living/carbon/human/H = usr
			H.sec_hud_set_ID()
		authenticated = 0

	if(href_list["dept"])
		var/lastdpt = dptdest
		dptdest = input(usr, "Какой отдел?", "Выберите отдел", "") as null|anything in alldepartments
		if(!dptdest) dptdest = lastdpt

	if(href_list["auth"])
		if ( (!( authenticated ) && (scan)) )
			if (check_access(scan))
				authenticated = 1

	if(href_list["logout"])
		authenticated = 0

	updateUsrDialog()

/obj/machinery/faxmachine/attackby(obj/item/O, mob/user)

	if(istype(O, /obj/item/weapon/paper))
		if(!tofax)
			user.drop_from_inventory(O, src)
			tofax = O
			to_chat(user, "<span class='notice'>You insert the paper into \the [src].</span>")
			flick("faxsend", src)
			updateUsrDialog()
		else
			to_chat(user, "<span class='notice'>There is already something in \the [src].</span>")

	else if(istype(O, /obj/item/weapon/card/id))

		var/obj/item/weapon/card/id/idcard = O
		if(!scan)
			usr.drop_from_inventory(idcard, src)
			idcard.loc = src
			scan = idcard
			if(ishuman(usr))
				var/mob/living/carbon/human/H = usr
				H.sec_hud_set_ID()

	else if(iswrench(O))
		default_unfasten_wrench(user, O)

/proc/centcomm_fax(mob/sender, obj/item/weapon/paper/P, obj/machinery/faxmachine/fax)
	var/msg = text("<span class='notice'><b>[] [] [] [] [] [] []</b>: Receiving '[P.name]' via secure connection ...[]</span>",
	"<font color='orange'>CENTCOMM FAX: </font>[key_name(sender, 1)]",
	"(<a href='?_src_=holder;adminplayeropts=\ref[sender]'>PP</a>)",
	"(<a href='?_src_=vars;Vars=\ref[sender]'>VV</a>)",
	"(<a href='?_src_=holder;subtlemessage=\ref[sender]'>SM</a>)",
	ADMIN_JMP(sender),
	"(<a href='?_src_=holder;secretsadmin=check_antagonist'>CA</a>)",
	"(<a href='?_src_=holder;CentcommFaxReply=\ref[sender];CentcommFaxReplyDestination=\ref[fax.department]'>RPLY</a>)",
	"<a href='?_src_=holder;CentcommFaxViewInfo=\ref[P.info];CentcommFaxViewStamps=\ref[P.stamp_text]'>view message</a>")  // Some weird BYOND bug doesn't allow to send \ref like `[P.info + P.stamp_text]`.

	for(var/client/C as anything in admins)
		to_chat(C, msg)

	send_fax(sender, P, "Central Command")

	add_communication_log(type = "fax-station", author = sender.name, content = P.info + "\n" + P.stamp_text)

	for(var/client/X in global.admins)
		X.mob.playsound_local(null, 'sound/machines/fax_centcomm.ogg', VOL_NOTIFICATIONS, vary = FALSE, frequency = null, ignore_environment = TRUE)

	world.send2bridge(
		type = list(BRIDGE_ADMINCOM),
		attachment_title = ":fax: **[key_name(sender)]** sent fax to ***Centcomm***",
		attachment_msg = strip_html_properly(replacetext((P.info + "\n" + P.stamp_text),"<br>", "\n")),
		attachment_footer = get_admin_counts_formatted(),
		attachment_color = BRIDGE_COLOR_ADMINCOM,
	)

/proc/send_fax(sender, obj/item/weapon/paper/P, department)
	for(var/obj/machinery/faxmachine/F in allfaxes)
		if((department == "Все" || F.department == department) && !( F.stat & (BROKEN|NOPOWER) ))
			F.print_fax(P.create_self_copy())

	log_fax("[sender] sending [P.name] to [department]: [P.info]")

/obj/machinery/faxmachine/proc/print_fax(obj/item/weapon/paper/P)
	set waitfor = FALSE

	playsound(src, "sound/items/polaroid1.ogg", VOL_EFFECTS_MASTER)
	flick("faxreceive", src)

	sleep(20)

	P.loc = loc
	audible_message("Получено сообщение.")
