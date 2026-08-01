'use strict'
TABS.servos = {}

TABS.servos.initialize = (callback) ->
    self = this

    get_servo_configurations = ->
        MSP.send_message MSPCodes.MSP_SERVO_CONFIGURATIONS, false, false, get_servo_mix_rules
        return

    get_servo_mix_rules = ->
        MSP.send_message MSPCodes.MSP_SERVO_MIX_RULES, false, false, get_rc_data
        return

    get_rc_data = ->
        MSP.send_message MSPCodes.MSP_RC, false, false, get_boxnames_data
        return

    get_boxnames_data = ->
        MSP.send_message MSPCodes.MSP_BOXNAMES, false, false, load_html
        return

    load_html = ->
        $('#content').load './tabs/servos.html', process_html
        return

    update_ui = ->
        `var i`

        process_servos = (name, alternate, obj) ->
            $('div.supported_wrapper').show()
            ornithopterGlideDegreeNumberElement = $('input[name="ornithopterGlideDegree-number"]')
            ornithopterGlideDegreeNumberElement.val SERVO_CONFIG.ornithopter_glide_deg / 1
            $('div.tab-servos table.fields').append '                <tr>                     <td style="text-align: center">' + name + '</td>                    <td class="middle"><input type="number" min="500" max="2500" value="' + SERVO_CONFIG[obj].middle + '" /></td>                    <td class="min"><input type="number" min="500" max="2500" value="' + SERVO_CONFIG[obj].min + '" /></td>                    <td class="max"><input type="number" min="500" max="2500" value="' + SERVO_CONFIG[obj].max + '" /></td>                    ' + servoCheckbox + '                    <td class="direction">                    </td>                </tr>             '
            if SERVO_CONFIG[obj].indexOfChannelToForward >= 0
                $('div.tab-servos table.fields tr:last td.channel input').eq(SERVO_CONFIG[obj].indexOfChannelToForward).prop 'checked', true
            # adding select box and generating options
            $('div.tab-servos table.fields tr:last td.direction').append '                <select class="rate" name="rate"></select>            '
            select = $('div.tab-servos table.fields tr:last td.direction select')
            i = 100
            while i > -101
                select.append '<option value="' + i + '">Rate: ' + i + '%</option>'
                i--
            # select current rate
            select.val SERVO_CONFIG[obj].rate
            $('div.tab-servos table.fields tr:last').data 'info', 'obj': obj
            # UI hooks
            # only one checkbox for indicating a channel to forward can be selected at a time, perhaps a radio group would be best here.
            $('div.tab-servos table.fields tr:last td.channel input').click ->
                if $(this).is(':checked')
                    $(this).parent().parent().find('.channel input').not($(this)).prop 'checked', false
                return
            return

        servos_update = (save_configuration_to_eeprom) ->

            send_servo_mixer_rules = ->
                mspHelper.sendServoConfigurations save_to_eeprom
                return

            save_to_eeprom = ->
                if save_configuration_to_eeprom
                    MSP.send_message MSPCodes.MSP_EEPROM_WRITE, false, false, ->
                        GUI.log i18n.getMessage('servosEepromSave')
                        return
                return

            $('div.tab-servos table.fields tr:not(".main")').each ->
                info = $(this).data('info')
                selection = $('.channel input', this)
                channelIndex = parseInt(selection.index(selection.filter(':checked')))
                if channelIndex == -1
                    channelIndex = undefined
                SERVO_CONFIG[info.obj].indexOfChannelToForward = channelIndex
                SERVO_CONFIG[info.obj].middle = parseInt($('.middle input', this).val())
                SERVO_CONFIG[info.obj].min = parseInt($('.min input', this).val())
                SERVO_CONFIG[info.obj].max = parseInt($('.max input', this).val())
                val = parseInt($('.direction select', this).val())
                SERVO_CONFIG[info.obj].rate = val
                return
            SERVO_CONFIG.ornithopter_glide_deg = parseInt($('input[name=ornithopterGlideDegree-number]', this).val())
            SERVO_CONFIG.ornithopter_glide_deg_sent = false
            #
            # send data to FC
            #
            mspHelper.sendServoConfigurations send_servo_mixer_rules
            return

        if semver.lt(CONFIG.apiVersion, '1.12.0') or SERVO_CONFIG.length == 0
            $('.tab-servos').removeClass 'supported'
            return
        $('.tab-servos').addClass 'supported'
        servoCheckbox = ''
        servoHeader = ''
        i = 0
        while i < RC.active_channels - 4
            servoHeader = servoHeader + '                <th >A' + i + 1 + '</th>            '
            i++
        servoHeader = servoHeader + '<th style="width: 110px" i18n="servosDirectionAndRate"></th>'
        i = 0
        while i < RC.active_channels
            servoCheckbox = servoCheckbox + '                <td class="channel"><input type="checkbox"/></td>            '
            i++
        $('div.tab-servos table.fields tr.main').append servoHeader
        # drop previous table
        $('div.tab-servos table.fields tr:not(:first)').remove()
        servoIndex = 0
        while servoIndex < 8
            process_servos 'Servo ' + servoIndex, '', servoIndex, false
            servoIndex++
        # UI hooks for dynamically generated elements
        $('table.directions select, table.directions input, table.fields select, table.fields input').change ->
            if $('div.live input').is(':checked')
                # apply small delay as there seems to be some funky update business going wrong
                GUI.timeout_add 'servos_update', servos_update, 10
            return
        $('a.update').click ->
            servos_update true
            return
        return

    process_html = ->
        update_ui()
        # translate to user-selected language
        i18n.localizePage()
        # status data pulled via separate timer with static speed
        GUI.interval_add 'status_pull', (->
            MSP.send_message MSPCodes.MSP_STATUS
            return
        ), 250, true
        GUI.content_ready callback
        return

    if GUI.active_tab != 'servos'
        GUI.active_tab = 'servos'
    get_servo_configurations()
    return

TABS.servos.cleanup = (callback) ->
    if callback
        callback()
    return

