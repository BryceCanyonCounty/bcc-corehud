FeatherMenu = exports["feather-menu"].initiate()

BCCCoreHudMenu = FeatherMenu:RegisterMenu("bcc:corehud:mainmenu", {
        top = '3%',
        left = '3%',
        ['720width'] = '400px',
        ['1080width'] = '500px',
        ['2kwidth'] = '600px',
        ['4kwidth'] = '800px',
        style = {
            --['background-image'] = 'url("nui://bcc-craft/assets/background.png")',
            --['background-size'] = 'cover',
            --['background-repeat'] = 'no-repeat',
            --['background-position'] = 'center',
            --['background-color'] = 'rgba(55, 33, 14, 0.7)', -- A leather-like brown
            --['border'] = '1px solid #654321',
            --['font-family'] = 'Times New Roman, serif',
            --['font-size'] = '38px',
            --['color'] = '#ffffff',
            --['padding'] = '10px 20px',
            --['margin-top'] = '5px',
            --['cursor'] = 'pointer',
            --['box-shadow'] = '3px 3px #333333',
            --['text-transform'] = 'uppercase',
        },
        contentslot = {
            style = {
                ['height'] = '450px',
                ['min-height'] = '300px'
            }
        },
    },
    {
        opened = function()
            DisplayRadar(false)
        end,
        closed = function()
            DisplayRadar(true)
            RefreshSliders()
        end
    }
)
