"use strict"

function scrollToStartOfTranscript() {
    document.querySelector('#banner').remove();
    document.querySelector('#social_bar').remove();
    var headers = Array.prototype.filter.call(document.querySelectorAll('h3'), function(node) { return true });
    var firstTranscriptHeader = headers.filter( function(node) { return node.id.match(/.*0{3,4}.*/); })
    if (firstTranscriptHeader.length == 1) {
        firstTranscriptHeader[0].scrollIntoView()
    }
}

function transcriptHeaders() {
    var headers = Array.prototype.filter.call(document.querySelectorAll('h3'), function(node) { return true });
    return headers.filter( function(node) { return node.id.match(/.*\d{3,4}.*/); })
}

function scrollToTranscriptHeaderForTime(seconds) {
    if (document.querySelector('#social_bar') != null) {
        document.querySelector('#social_bar').remove();
    }
    var th = transcriptHeaders()
    var timeCode = Math.floor(seconds / 60) * 100 + seconds % 60
    var paddedTimeCode3 = (timeCode < 10 ? "00" : (timeCode < 100 ? "0" : "")) + (""+timeCode)
    var paddedTimeCode4 = (timeCode < 10 ? "000" : (timeCode < 100 ? "00" : (timeCode < 1000 ? "0" : ""))) + (""+timeCode)
    var minDistance = Math.pow(2,32)
    var closestPreceedingHeader = Array.prototype.filter.call(th, function(header) {
        var headerTimeCode = header.id.match(/.*-(\d{3,4}).*/)[1]
        if (Math.abs(headerTimeCode - timeCode) < minDistance && timeCode > headerTimeCode) {
            minDistance = Math.abs(headerTimeCode - timeCode)
            return true
        } else {
            return false
        }
    });
    closestPreceedingHeader[closestPreceedingHeader.length-1].scrollIntoView()
}

scrollToStartOfTranscript();
