jQuery = require 'jquery'

jQuery ($) ->
  console.log "Hello World!!!"
  $('.col-50').each (index, element) ->
    $col_height = $(window).height() - $('.header').outerHeight() - $('.footer').outerHeight()
    console.log($('.footer').height())
    $(element).height($col_height)
    return
  return
