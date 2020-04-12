script_name('Trinity News Helper')
script_author('akionka')
script_version('1.0.0')
script_moonloader(27)

require 'libstd.deps' {
  'fyp:samp-lua',
  'fyp:moon-imgui',
  'Akionka:lua-semver',
}

local vkeys = require 'vkeys'
local sampev = require 'lib.samp.events'
local encoding = require 'encoding'
encoding.default = 'cp1251'
local u8 = encoding.UTF8
local imgui = require 'imgui'
local v = require 'semver'

local prefix = 'TNH'
local updatesAvaliable = false
local lastTagAvaliable = '1.0.0'

local doCatchAds = false
local lastAdText, lastEditedAdText

local mainWindowState = imgui.ImBool(false)
local addNewAdWindowState = imgui.ImBool(false)
local editableAdBuffer = imgui.ImBuffer(256)
local addNewAdOrigBuffer = imgui.ImBuffer(256)
local addNewAdEditedBuffer = imgui.ImBuffer(256)
local acceptAsIsBuffer = imgui.ImBool(false)
local selectedTab = 2
local selectedAd = ""
local editableAd = ""

local data = {
  ads = {
    --[[
      {
        originalText, -- Текст принимаемого объявления
        editedText, -- Текст отредактированного объявления
        acceptAsIs, -- Принимать как есть
        accept, -- Принимать вообще
      }
    ]]
  },
  settings = {
    autoStart = false,
    autoCheckUpdates = true,
    autoAddNewAds = false,
  }
}

function sampev.onServerMessage(color, text)
  if not doCatchAds or sampIsDialogActive() or isGamePaused() or sampIsChatInputActive() then return end
  if color == -290866945 and text:match(u8:decode('На модерацию поступило новое объявление. Всего на модерации находится {ffffff}(%d+){EEA9B8} объявлени?.')) then
    sampSendChat('/admod')
    return true
  end
end

function sampev.onSendDialogResponse(id, btn, list, text)
  if id == 3420 and btn == 1 then
    local exists, index = doesAdExist(lastAdText)
    if not exists then
      if data['settings']['autoAddNewAds'] then addNewAd(lastAdText, '', true, true) saveData() end
      addNewAdWindowState.v = not data['settings']['autoAddNewAds']
      addNewAdOrigBuffer.v = lastAdText
      addNewAdEditedBuffer.v = u8:encode(text)
      acceptAsIsBuffer.v = true
    end
  elseif id == 3425 and btn == 1 then
    local exists, index = doesAdExist(lastAdText)
    if not exists then
      if data['settings']['autoAddNewAds'] then addNewAd(lastAdText, lastEditedAdText, false, true) saveData() end
      addNewAdWindowState.v = not data['settings']['autoAddNewAds']
      addNewAdOrigBuffer.v = lastAdText
      addNewAdEditedBuffer.v = lastEditedAdText
      acceptAsIsBuffer.v = false
    end
  end
end

function sampev.onShowDialog(id, style, title, btn1, btn2, text)
  if id == 3420 then
    lastAdText = u8:encode(stringToLower(text:match(u8:decode('{ffffff}Текст:{abcdef} (.+){ffffff}'))))
    local exists, index = doesAdExist(lastAdText)
    if exists then
      if data['ads'][index[1]]['acceptAsIs'] then
        sampSendDialogResponse(id, 1, 0, '')
        return false
      else
        sampSendDialogResponse(id, 0, 0, '')
        return false
      end
    end
  end

  if id == 3421 then sampSendDialogResponse(id, 1, 0, '') return false end

  if id == 3422 then
    local exists, index = doesAdExist(lastAdText)
    if exists then
      if data['ads'][index[1]]['accept'] then
        sampSendDialogResponse(id, 1, 1, '')
        return false
      else
        sampSendDialogResponse(id, 1, 0, '')
        return false
      end
    end
  end

  if id == 3423 then
    local exists, index = doesAdExist(lastAdText)
    if exists then
      sampSendDialogResponse(id, 1, 0, u8:decode(data['ads'][index[1]]['editedText']))
      return false
    end
  end

  if id == 3425 then
    lastEditedAdText = u8:encode(text:match(u8:decode('Новый текст объявления: {abcdef}(.+)\n\n')))
    sampSendDialogResponse(id, 1, 0, '')
    return false
  end
  return {id, style, title..' | '..id, btn1, btn2, text}
end

function imgui.OnDrawFrame()
  if mainWindowState.v then
    local resX, resY = getScreenResolution()
    imgui.SetNextWindowSize(imgui.ImVec2(700, 350), 2)
    imgui.SetNextWindowPos(imgui.ImVec2(resX/2, resY/2), 2, imgui.ImVec2(0.5, 0.5))
    imgui.Begin('Trinity News Helper v'..thisScript()['version'], mainWindowState)
      imgui.BeginGroup()
        imgui.BeginChild('Left Panel', imgui.ImVec2(100, 0), true)
          if imgui.Selectable('Списки', selectedTab == 1) then selectedTab = 1  end
          if imgui.Selectable('Настройки', selectedTab == 2) then selectedTab = 2  end
          if imgui.Selectable('Информация', selectedTab == 3) then selectedTab = 3  end
        imgui.EndChild()
      imgui.EndGroup()

      imgui.SameLine()

      if selectedTab == 1 then
        imgui.BeginGroup()
          imgui.BeginChild('Center panel', imgui.ImVec2(0, -imgui.GetItemsLineHeightWithSpacing()-15), true)
            for i, v in ipairs(data['ads']) do
              if v['originalText'] == editableAd then
                imgui.PushItemWidth(200)
                -- if not data['ads'][i]['acceptAsIs'] then
                  imgui.InputText('', editableAdBuffer)
                -- end
                imgui.PopItemWidth()
                imgui.SameLine()
                if imgui.Button('OK') then changeAdData(editableAd, editableAdBuffer.v, data['ads'][i]['acceptAsIs'], true) editableAdBuffer.v = '' editableAd = '' saveData() end
                imgui.SameLine()
                if imgui.Button('Отмена') then editableAdBuffer.v = '' editableAd = '' end
                imgui.SameLine()
                if imgui.Checkbox('Как есть', imgui.ImBool(data['ads'][i]['acceptAsIs'])) then
                  changeAdData(editableAd.v, editableAdBuffer.v, not data['ads'][i]['acceptAsIs'], true)
                end
                imgui.SameLine()
                if imgui.Button('Удалить') then removeAd(v['originalText']) editableAdBuffer.v = '' editableAd = '' saveData() end
              elseif imgui.Selectable(v['originalText'], selectedAd == v['originalText'], imgui.SelectableFlags.AllowDoubleClick) then
                if imgui.IsMouseDoubleClicked(0) then
                  editableAd = v['originalText']
                  editableAdBuffer.v = v['editedText']
                end
                selectedAd = k
              end
            end
          imgui.EndChild()
          imgui.BeginChild('Center bottom', imgui.ImVec2(0, 0), true)
          if imgui.Button('Добавить') then imgui.OpenPopup('Добавление объявления') end
          imgui.SameLine()
          if imgui.Button('Удалить все') then imgui.OpenPopup('Удаление всех объявлений') end
          if imgui.BeginPopupModal('Добавление объявления', nil, 64) then
            imgui.InputText('Текст оригинального объявления', addNewAdOrigBuffer)
            imgui.Checkbox('Отправлять как есть', acceptAsIsBuffer)
            if not acceptAsIsBuffer.v then
              imgui.InputText('Текст отредактированного объявления', addNewAdEditedBuffer)
            end
            imgui.Separator()
            imgui.SetCursorPosX((imgui.GetWindowWidth() - 240 + imgui.GetStyle().ItemSpacing.x) / 2)
            if imgui.Button('Готово', imgui.ImVec2(120, 0)) and (acceptAsIsBuffer.v or addNewAdEditedBuffer.v ~= '') and addNewAdOrigBuffer.v ~= '' and data['ads'][addNewAdOrigBuffer.v] == nil then
              data['ads'][addNewAdOrigBuffer.v] = {
                editedText = addNewAdEditedBuffer.v,
                acceptAsIs = acceptAsIsBuffer.v,
                accept = true
              }
              addNewAdOrigBuffer.v = ''
              addNewAdEditedBuffer.v = ''
              acceptAsIsBuffer.v = false
              saveData()
              imgui.CloseCurrentPopup()
            end
            imgui.SameLine()
            if imgui.Button('Отмена', imgui.ImVec2(120, 0)) then imgui.CloseCurrentPopup() end
            imgui.EndPopup()
          end
          if imgui.BeginPopupModal('Удаление всех объявлений', nil, 64) then
            imgui.Text('Вы действительно хотите удалить ВСЕ объявления?\nДанная операция является необратимой.\n\n')
            imgui.Separator()
            imgui.SetCursorPosX((imgui.GetWindowWidth() - 240 + imgui.GetStyle().ItemSpacing.x) / 2)
            if imgui.Button('Да', imgui.ImVec2(120, 0)) then
              removeAllAds()
              saveData()
              imgui.CloseCurrentPopup()
            end
            imgui.SameLine()
            if imgui.Button('Нет', imgui.ImVec2(120, 0)) then imgui.CloseCurrentPopup() end
            imgui.EndPopup()
          end
          imgui.EndChild()
        imgui.EndGroup()
      elseif selectedTab == 2 then
        imgui.BeginGroup()
          imgui.BeginChild('Settings panel', imgui.ImVec2(0, 0), true)
          if imgui.Checkbox('Автоматически запускать ловлю объявлений', imgui.ImBool(data['settings']['autoStart'])) then
            data['settings']['autoStart'] = not data['settings']['autoStart']
            saveData()
          end
          if imgui.Checkbox('Автоматически проверять обновления', imgui.ImBool(data['settings']['autoCheckUpdates'])) then
            data['settings']['autoCheckUpdates'] = not data['settings']['autoCheckUpdates']
            saveData()
          end
          if imgui.Checkbox('Автоматически добавлять объявления в список', imgui.ImBool(data['settings']['autoAddNewAds'])) then
            data['settings']['autoAddNewAds'] = not data['settings']['autoAddNewAds']
            saveData()
          end
          imgui.EndChild()
        imgui.EndGroup()

      elseif selectedTab == 3 then
        imgui.BeginGroup()
          imgui.BeginChild('Center panel', imgui.ImVec2(0, 0), true)
            imgui.Text('Название: Trinity News Helper')
            imgui.Text('Автор: Akionka')
            imgui.Text('Версия: '..thisScript()['version'])
            imgui.Text('Команды: /tcad, /tnewsh')
            if updatesAvaliable then
              if imgui.Button('Скачать обновление', imgui.ImVec2(150, 0)) then
                update()
                mainWindowState.v = false
              end
            else
              if imgui.Button('Проверить обновления', imgui.ImVec2(150, 0)) then
                checkUpdates()
              end
            end
            imgui.SameLine()
            if imgui.Button('Группа ВКонтакте', imgui.ImVec2(150, 0)) then os.execute('explorer "https://vk.com/akionkamods"') end
            if imgui.Button('Bug report [VK]', imgui.ImVec2(150, 0)) then os.execute('explorer "https://vk.com/akionka"') end
            imgui.SameLine()
            if imgui.Button('Bug report [Telegram]', imgui.ImVec2(150, 0)) then os.execute('explorer "https://teleg.run/akionka"') end
          imgui.EndChild()
        imgui.EndGroup()
      end
    imgui.End()
  end
  if addNewAdWindowState.v then
    local resX, resY = getScreenResolution()
    imgui.SetNextWindowSize(imgui.ImVec2(576, -imgui.GetItemsLineHeightWithSpacing()*6), 2)
    imgui.SetNextWindowPos(imgui.ImVec2(resX/2, resY/2), 2, imgui.ImVec2(0.5, 0.5))
    imgui.Begin('Trinity News Helper v'..thisScript()['version']..' | Добавление нового объявления', addNewAdWindowState, imgui.WindowFlags.NoResize)
      imgui.Text('Хотите добавить новое объявление?')
      imgui.Text('Текст оригинального объявления: '..addNewAdOrigBuffer.v)
      if imgui.Checkbox('Отправлять как есть', acceptAsIsBuffer) then acceptAsIsBuffer.v = not acceptAsIsBuffer.v end
      if acceptAsIsBuffer.v or imgui.Text('Текст отредактированного объявления: '..addNewAdEditedBuffer.v..'\n\n') then end
      imgui.Separator()
      imgui.SetCursorPosX((imgui.GetWindowWidth() - 240 + imgui.GetStyle().ItemSpacing.x) / 2)
      if imgui.Button('Да', imgui.ImVec2(120, 0)) then
        addNewAd(addNewAdOrigBuffer.v, addNewAdEditedBuffer.v, acceptAsIsBuffer.v, accept)
        addNewAdOrigBuffer.v = ''
        addNewAdEditedBuffer.v = ''
        addNewAdWindowState.v = false
        acceptAsIsBuffer.v = false
        saveData()
      end
      imgui.SameLine()
      if imgui.Button('Нет', imgui.ImVec2(120, 0)) then
        addNewAdOrigBuffer.v = ''
        addNewAdEditedBuffer.v = ''
        addNewAdWindowState.v = false
        acceptAsIsBuffer.v = false
      end
    imgui.End()
  end
end

function main()
  if not isSampfuncsLoaded() or not isSampLoaded() then return end
  while not isSampAvailable() do wait(0) end
  if not doesDirectoryExist(getWorkingDirectory()..'\\config') then createDirectory(getWorkingDirectory()..'\\config') end

  local ip = sampGetCurrentServerAddress()
  if ip ~= '185.169.134.83' and ip ~= '185.169.134.84' and ip ~= '185.169.134.85' then
    print(u8:decode('Скрипт поддерживает только сервера Trinity GTA'))
    thisScript():unload()
  end

  applyCustomStyle()
  loadData()

  doCatchAds = data['settings']['autoStart'] or false
  if data['settings']['autoCheckUpdates'] then checkUpdates() end

  sampRegisterChatCommand('tcad', function()
    doCatchAds = not doCatchAds
    msg(doCatchAds and 'Started' or 'Disabled')
  end)
  sampRegisterChatCommand('tnewsh', function()
    mainWindowState.v = not mainWindowState.v
  end)
  while true do
    wait(0)
    imgui.Process = mainWindowState.v or addNewAdWindowState.v
   end
end

function saveData()
  local configFile = io.open(getWorkingDirectory()..'\\config\\trinity-news-helper.json', 'w+')
  configFile:write(encodeJson(data))
  configFile:close()
end

function loadData()
  local function loadSubData(table, dest)
    for k, v in pairs(table) do
      if type(v) == 'table' then
        loadSubData(v, dest[k])
      end
      dest[k] = v
    end
  end

  if not doesFileExist(getWorkingDirectory()..'\\config\\trinity-news-helper.json') then
    local configFile = io.open(getWorkingDirectory()..'\\config\\trinity-news-helper.json', 'w+')
    configFile:write(encodeJson(data))
    configFile:close()
    return
  end

  local configFile = io.open(getWorkingDirectory()..'\\config\\trinity-news-helper.json', 'r')
  local tempData = decodeJson(configFile:read('*a'))
  loadSubData(tempData['settings'], data['settings'])
  data['ads'] = tempData['ads'] or data['ads']
  configFile:close()
end

function checkUpdates()
  local fpath = os.tmpname()
  if doesFileExist(fpath) then os.remove(fpath) end
  downloadUrlToFile('https://api.github.com/repos/akionka/trinity-news-helper/releases', fpath, function(_, status, _, _)
    if status == 58 then
      if doesFileExist(fpath) then
        local f = io.open(fpath, 'r')
        if f then
          local info = decodeJson(f: read('*a'))
          f:close()
          os.remove(fpath)
          if v(info[1]['tag_name']) > v(thisScript()['version']) then
            updatesAvaliable = true
            lastTagAvaliable = info[1]['tag_name']
            msg('Найдено объявление. Текущая версия: {9932cc}'..thisScript()['version']..'{FFFFFF}, новая версия: {9932cc}'..info[1]['tag_name']..'{FFFFFF}')
            return true
          else
            updatesAvaliable = false
            msg('У вас установлена самая свежая версия скрипта.')
          end
        else
          updatesAvaliable = false
          msg('Что-то пошло не так, упс. Попробуйте позже.')
        end
      end
    end
  end)
end

function update()
  downloadUrlToFile('https://github.com/akionka/trinity-news-helper/releases/download/'..lastTagAvaliable..'/trinity-news-helper.lua', thisScript()['path'], function(_, status, _, _)
    if status == 6 then
      msg('Новая версия установлена! Чтобы скрипт обновился нужно либо перезайти в игру, либо ...')
      msg('... если у вас есть автоперезагрузка скриптов, то новая версия уже готова и снизу вы увидите приветственное сообщение.')
      msg('Если что-то пошло не так, то сообщите мне об этом в VK или Telegram > {2980b0}vk.com/akionka teleg.run/akionka{FFFFFF}.')
      thisScript()['reload']()
    end
  end)
end

function msg(text)
  sampAddChatMessage(u8:decode('['..prefix..']: '..text), -1)
end

function stringToLower(s)
  for i = 192, 223 do
    s = s:gsub(_G.string.char(i), _G.string.char(i + 32))
  end
  s = s:gsub(_G.string.char(168), _G.string.char(184))
  return s:lower()
end

function applyCustomStyle()
  imgui.SwitchContext()
  local style = imgui.GetStyle()
  local colors = style.Colors
  local clr = imgui.Col
  local function ImVec4(color)
    local r = bit.band(bit.rshift(color, 24), 0xFF)
    local g = bit.band(bit.rshift(color, 16), 0xFF)
    local b = bit.band(bit.rshift(color, 8), 0xFF)
    local a = bit.band(color, 0xFF)
    return imgui.ImVec4(r/255, g/255, b/255, a/255)
  end

  style['WindowRounding'] = 10.0
  style['WindowTitleAlign'] = imgui.ImVec2(0.5, 0.5)
  style['ChildWindowRounding'] = 5.0
  style['FrameRounding'] = 5.0
  style['ItemSpacing'] = imgui.ImVec2(5.0, 5.0)
  style['ScrollbarSize'] = 13.0
  style['ScrollbarRounding'] = 5

  colors[clr['Text']] = ImVec4(0xFFFFFFFF)
  colors[clr['TextDisabled']] = ImVec4(0x212121FF)
  colors[clr['WindowBg']] = ImVec4(0x212121FF)
  colors[clr['ChildWindowBg']] = ImVec4(0x21212180)
  colors[clr['PopupBg']] = ImVec4(0x212121FF)
  colors[clr['Border']] = ImVec4(0xFFFFFF10)
  colors[clr['BorderShadow']] = ImVec4(0x21212100)
  colors[clr['FrameBg']] = ImVec4(0xC3E88D90)
  colors[clr['FrameBgHovered']] = ImVec4(0xC3E88DFF)
  colors[clr['FrameBgActive']] = ImVec4(0x61616150)
  colors[clr['TitleBg']] = ImVec4(0x212121FF)
  colors[clr['TitleBgActive']] = ImVec4(0x212121FF)
  colors[clr['TitleBgCollapsed']] = ImVec4(0x212121FF)
  colors[clr['MenuBarBg']] = ImVec4(0x21212180)
  colors[clr['ScrollbarBg']] = ImVec4(0x212121FF)
  colors[clr['ScrollbarGrab']] = ImVec4(0xEEFFFF20)
  colors[clr['ScrollbarGrabHovered']] = ImVec4(0xEEFFFF10)
  colors[clr['ScrollbarGrabActive']] = ImVec4(0x80CBC4FF)
  colors[clr['ComboBg']] = colors[clr['PopupBg']]
  colors[clr['CheckMark']] = ImVec4(0x212121FF)
  colors[clr['SliderGrab']] = ImVec4(0x212121FF)
  colors[clr['SliderGrabActive']] = ImVec4(0x80CBC4FF)
  colors[clr['Button']] = ImVec4(0xC3E88D90)
  colors[clr['ButtonHovered']] = ImVec4(0xC3E88DFF)
  colors[clr['ButtonActive']] = ImVec4(0x61616150)
  colors[clr['Header']] = ImVec4(0x151515FF)
  colors[clr['HeaderHovered']] = ImVec4(0x252525FF)
  colors[clr['HeaderActive']] = ImVec4(0x303030FF)
  colors[clr['Separator']] = colors[clr['Border']]
  colors[clr['SeparatorHovered']] = ImVec4(0x212121FF)
  colors[clr['SeparatorActive']] = ImVec4(0x212121FF)
  colors[clr['ResizeGrip']] = ImVec4(0x212121FF)
  colors[clr['ResizeGripHovered']] = ImVec4(0x212121FF)
  colors[clr['ResizeGripActive']] = ImVec4(0x212121FF)
  colors[clr['CloseButton']] = ImVec4(0x212121FF)
  colors[clr['CloseButtonHovered']] = ImVec4(0xD41223FF)
  colors[clr['CloseButtonActive']] = ImVec4(0xD41223FF)
  colors[clr['PlotLines']] = ImVec4(0x212121FF)
  colors[clr['PlotLinesHovered']] = ImVec4(0x212121FF)
  colors[clr['PlotHistogram']] = ImVec4(0x212121FF)
  colors[clr['PlotHistogramHovered']] = ImVec4(0x212121FF)
  colors[clr['TextSelectedBg']] = ImVec4(0x212121FF)
  colors[clr['ModalWindowDarkening']] = ImVec4(0x21212180)
end

function sortByOriginalText(a, b) return a['originalText'] < b['originalText'] end
function fcompvalOriginalText(value) return value and value['originalText'] or nil end

function addNewAd(originalText, editedText, acceptAsIs, accept)
  table.bininsert(data['ads'], {
    originalText = originalText,
    editedText = editedText,
    acceptAsIs = acceptAsIs,
    accept = accept,
  }, sortByOriginalText)
end

function removeAd(originalText)
  local exists, index = doesAdExist(originalText)
  if exists then table.remove(data['ads'], index[1]) end
end

function removeAllAds()
  data['ads'] = {}
end

function doesAdExist(originalText)
  local result = table.binsearch(data['ads'], originalText, fcompvalOriginalText, false)
  return not not result, result
end

function changeAdData(originalText, editedText, acceptAsIs, accept)
  local exists, index = doesAdExist(originalText)
  if exists then
    data['ads'][index[1]] = {
      originalText = originalText,
      editedText = editedText,
      acceptAsIs = acceptAsIs,
      accept = accept,
    }
    resortAds()
  end
end

function resortAds()
  table.sort(data['ads'], sortByOriginalText)
end


local default_fcompval = function(value) return value end
local fcompf = function(a, b) return a < b end
local fcompr = function(a, b) return a > b end
function table.binsearch(tbl, value, fcompval, reversed)
   local fcompval = fcompval or default_fcompval
   local fcomp = reversed and fcompr or fcompf
   local iStart, iEnd, iMid = 1, #tbl, 0
   while iStart <= iEnd do
      iMid = math.floor((iStart+iEnd)/2)
      local value2 = fcompval(tbl[iMid])
      if value == value2 then
         local tfound, num = {iMid, iMid}, iMid - 1
         while value == fcompval(tbl[num]) do
            tfound[1], num = num, num - 1
         end
         num = iMid + 1
         while value == fcompval(tbl[num]) do
            tfound[2], num = num, num + 1
         end
         return tfound
      elseif fcomp(value, value2)  then
         iEnd = iMid - 1
      else
         iStart = iMid + 1
      end
   end
end

local fcomp_default = function(a, b) return a < b end
function table.bininsert(t, value, fcomp)
   local fcomp = fcomp or fcomp_default
   local iStart, iEnd, iMid, iState = 1, #t, 1, 0
   while iStart <= iEnd do
      iMid = math.floor((iStart+iEnd)/2)
      if fcomp(value,t[iMid]) then
         iEnd, iState = iMid - 1, 0
      else
         iStart, iState = iMid + 1, 1
      end
   end
   table.insert(t, (iMid+iState), value)
   return (iMid+iState)
end