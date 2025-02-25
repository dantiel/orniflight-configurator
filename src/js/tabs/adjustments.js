'use strict';

TABS.adjustments = {};

TABS.adjustments.initialize = function (callback) {
    var self = this;
    GUI.active_tab_ref = this;
    GUI.active_tab = 'adjustments';
    
    function get_adjustment_ranges() {
        MSP.send_message(MSPCodes.MSP_ADJUSTMENT_RANGES, false, false, get_box_ids);
    }

    function get_box_ids() {
        MSP.send_message(MSPCodes.MSP_BOXIDS, false, false, get_rc_data);
    }

    function get_rc_data() {
        MSP.send_message(MSPCodes.MSP_RC, false, false, load_html);
    }

    function load_html() {
        $('#content').load("./tabs/adjustments.html", process_html);
    }

    MSP.send_message(MSPCodes.MSP_BOXNAMES, false, false, get_adjustment_ranges);

    function addAdjustment(adjustmentIndex, adjustmentRange, auxChannelCount) {

        var template = $('#tab-adjustments-templates .adjustments .adjustment');
        var newAdjustment = template.clone();
        
        $(newAdjustment).attr('id', 'adjustment-' + adjustmentIndex);
        $(newAdjustment).data('index', adjustmentIndex);

        //
        // update selected slot
        //
        
        if (semver.lt(CONFIG.apiVersion, "1.42.0")) {
            var adjustmentList = $(newAdjustment).find('.adjustmentSlot .slot');
            adjustmentList.val(adjustmentRange.slotIndex);
        }

        //
        // populate source channel select box
        //
        
        var channelList = $(newAdjustment).find('.channelInfo .channel');
        var channelOptionTemplate = $(channelList).find('option');
        channelOptionTemplate.remove();
        for (var channelIndex = 0; channelIndex < auxChannelCount; channelIndex++) {
            var channelOption = channelOptionTemplate.clone();
            channelOption.text('AUX ' + (channelIndex + 1));
            channelOption.val(channelIndex);
            channelList.append(channelOption);
        }
        channelList.val(adjustmentRange.auxChannelIndex);

        //
        // update selected function
        //

        var functionList = $(newAdjustment).find('.functionSelection .function');
        // update list of selected functions

        functionList.val(adjustmentRange.adjustmentFunction);

        //
        // populate function channel select box
        //

        var switchList = $(newAdjustment).find('.functionSwitchChannel .channel');
        var switchOptionTemplate = $(switchList).find('option');
        switchOptionTemplate.remove();
        var switchOption;
        for (var switchIndex = 0; switchIndex < auxChannelCount; switchIndex++) {
            switchOption = switchOptionTemplate.clone();
            switchOption.text('AUX ' + (switchIndex + 1));
            switchOption.val(switchIndex);
            switchList.append(switchOption);
        }
        switchList.val(adjustmentRange.auxSwitchChannelIndex);

        //
        // configure range
        //
        
        var channel_range = {
                'min': [  900 ],
                'max': [ 2100 ]
            };

        var rangeValues = [1300, 1700];
        if (adjustmentRange.range != undefined) {
            rangeValues = [adjustmentRange.range.start, adjustmentRange.range.end];
        }

        var rangeElement = $(newAdjustment).find('.range');

        $(rangeElement).find('.channel-slider').noUiSlider({
            start: rangeValues,
            behaviour: 'snap-drag',
            margin: 50,
            step: 25,
            connect: true,
            range: channel_range,
            format: wNumb({
                decimals: 0
            })
        });

        $(newAdjustment).find('.channel-slider').Link('lower').to($(newAdjustment).find('.lowerLimitValue'));
        $(newAdjustment).find('.channel-slider').Link('upper').to($(newAdjustment).find('.upperLimitValue'));

        $(rangeElement).find(".pips-channel-range").noUiSlider_pips({
            mode: 'values',
            values: [900, 1000, 1200, 1400, 1500, 1600, 1800, 2000, 2100],
            density: 4,
            stepped: true
        });
        
        //
        // add the enable/disable behavior
        //
        
        var enableElement = $(newAdjustment).find('.enable');
        $(enableElement).data('adjustmentElement', newAdjustment);
        $(enableElement).change(function() {
            var adjustmentElement = $(this).data('adjustmentElement');
            if ($(this).prop("checked")) { 
                $(adjustmentElement).find(':input').prop("disabled", false);
                $(adjustmentElement).find('.channel-slider').removeAttr("disabled");
                var rangeElement = $(adjustmentElement).find('.range .channel-slider');
                var range = $(rangeElement).val();
                if (range[0] == range[1]) {
                    var defaultRangeValues = [1300, 1700];
                    $(rangeElement).val(defaultRangeValues);
                }
            } else {
                $(adjustmentElement).find(':input').prop("disabled", true);
                $(adjustmentElement).find('.channel-slider').attr("disabled", "disabled");
            }

            // keep this element enabled
            $(this).prop("disabled", false);
        });
        
        var isEnabled = (adjustmentRange.range.start != adjustmentRange.range.end); 
        $(enableElement).prop("checked", isEnabled).change();
        
        return newAdjustment;
    }

    function process_html() {

        self.adjust_template();

        var auxChannelCount = RC.active_channels - 4;

        var modeTableBodyElement = $('.tab-adjustments .adjustments tbody');
        for (var adjustmentIndex = 0; adjustmentIndex < ADJUSTMENT_RANGES.length; adjustmentIndex++) {
            var newAdjustment = addAdjustment(adjustmentIndex, ADJUSTMENT_RANGES[adjustmentIndex], auxChannelCount);
            modeTableBodyElement.append(newAdjustment);
        }
        

        if (semver.gte(CONFIG.apiVersion, "1.42.0")) {
            $('.tab-adjustments .adjustmentSlotsHelp').hide();
            $('.tab-adjustments .adjustmentSlotHeader').hide();
            $('.tab-adjustments .adjustmentSlot').hide();
        }

        // translate to user-selected language
        i18n.localizePage();

        // UI Hooks
        $('a.save').click(function () {

            // update internal data structures based on current UI elements
            var requiredAdjustmentRangeCount = ADJUSTMENT_RANGES.length;
            
            ADJUSTMENT_RANGES = [];
            
            var defaultAdjustmentRange = {
                slotIndex: 0,
                auxChannelIndex: 0,
                range: {
                    start: 900,
                    end: 900
                },
                adjustmentFunction: 0,
                auxSwitchChannelIndex: 0
            };

            $('.tab-adjustments .adjustments .adjustment').each(function () {
                var adjustmentElement = $(this);
                
                if ($(adjustmentElement).find('.enable').prop("checked")) {
                    var rangeValues = $(this).find('.range .channel-slider').val();
                    var slotIndex = 0;
                    if (semver.lt(CONFIG.apiVersion, "1.42.0")) {
                        slotIndex = parseInt($(this).find('.adjustmentSlot .slot').val());
                    }

                    var adjustmentRange = {
                        slotIndex: slotIndex,
                        auxChannelIndex: parseInt($(this).find('.channelInfo .channel').val()),
                        range: {
                            start: rangeValues[0],
                            end: rangeValues[1]
                        },
                        adjustmentFunction: parseInt($(this).find('.functionSelection .function').val()),
                        auxSwitchChannelIndex: parseInt($(this).find('.functionSwitchChannel .channel').val())
                    };
                    ADJUSTMENT_RANGES.push(adjustmentRange);
                } else {
                    ADJUSTMENT_RANGES.push(defaultAdjustmentRange);
                }
            });
            
            for (var adjustmentRangeIndex = ADJUSTMENT_RANGES.length; adjustmentRangeIndex < requiredAdjustmentRangeCount; adjustmentRangeIndex++) {
                ADJUSTMENT_RANGES.push(defaultAdjustmentRange);
            }
            
            //
            // send data to FC
            //
            mspHelper.sendAdjustmentRanges(save_to_eeprom);
            
            function save_to_eeprom() {
                MSP.send_message(MSPCodes.MSP_EEPROM_WRITE, false, false, function () {
                    GUI.log(i18n.getMessage('adjustmentsEepromSaved'));
                });
            }

        });

        function update_marker(auxChannelIndex, channelPosition) {
            if (channelPosition < 900) {
                channelPosition = 900;
            } else if (channelPosition > 2100) {
                channelPosition = 2100;
            }
            var percentage = (channelPosition - 900) / (2100-900) * 100;
            
            $('.adjustments .adjustment').each( function () {
                var auxChannelCandidateIndex = $(this).find('.channel').val();
                if (auxChannelCandidateIndex != auxChannelIndex) {
                    return;
                }
                
                $(this).find('.range .marker').css('left', percentage + '%');
            });
        }

        // data pulling functions used inside interval timer
        function get_rc_data() {
            MSP.send_message(MSPCodes.MSP_RC, false, false, update_ui);
        }

        function update_ui() {
            var auxChannelCount = RC.active_channels - 4;

            for (var auxChannelIndex = 0; auxChannelIndex < auxChannelCount; auxChannelIndex++) {
                update_marker(auxChannelIndex, RC.channels[auxChannelIndex + 4]);
            }           
        }

        // update ui instantly on first load
        update_ui();

        // enable data pulling
        GUI.interval_add('aux_data_pull', get_rc_data, 50);

        // status data pulled via separate timer with static speed
        GUI.interval_add('status_pull', function () {
            MSP.send_message(MSPCodes.MSP_STATUS);
        }, 250, true);

        GUI.content_ready(callback);
    }
};

TABS.adjustments.cleanup = function (callback) {
    if (callback) callback();
};

TABS.adjustments.adjust_template = function () {

    var selectFunction = $('#functionSelectionSelect');
    var elementsNumber;

    if (semver.gte(CONFIG.apiVersion, "1.41.0")) {
        elementsNumber = 32; // OSD Profile Select & LED Profile Select & Flap Speed Modificator
    } else if (semver.gte(CONFIG.apiVersion, "1.40.0")) {
        elementsNumber = 29; // PID Audio
    } else if (semver.gte(CONFIG.apiVersion, "1.39.0")) {
        elementsNumber = 26; // PID Audio
    } else if (semver.gte(CONFIG.apiVersion, "1.37.0")) {
        elementsNumber = 25; // Horizon Strength
    } else {
        elementsNumber = 24; // Setpoint transition
    }

    for (let i = 0; i < elementsNumber; i++) {
        selectFunction.append(new Option(i18n.getMessage('adjustmentsFunction' + i), i));
    }
    
    // For 1.40, the D Setpoint has been replaced, so we replace it with the correct values
    if (semver.gte(CONFIG.apiVersion, "1.40.0")) {

        var element22 = selectFunction.find("option[value='22']");
        var element23 = selectFunction.find("option[value='23']");

        // Change the "text"
        element22.text(i18n.getMessage('adjustmentsFunction22_2'));
        element23.text(i18n.getMessage('adjustmentsFunction23_2'));

        // Reorder, we insert it with the other FF elements to be coherent...
        element22.insertAfter(selectFunction.find("option[value='25']"));
        element23.insertAfter(selectFunction.find("option[value='28']"));
    }
};
