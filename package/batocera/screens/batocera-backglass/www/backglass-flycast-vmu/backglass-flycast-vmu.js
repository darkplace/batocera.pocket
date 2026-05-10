"use strict";

var VMU_SLOTS = [
    { slot: "A1", canvas: "vmu-a1" },
    { slot: "A2", canvas: "vmu-a2" }
];

function drawVmu(canvas, bytes) {
    var ctx = canvas.getContext("2d");
    var image = ctx.createImageData(48, 32);

    for (var i = 0; i < 48 * 32; i++) {
        var on = bytes[i] !== 0;
        var dst = i * 4;
        if (on) {
            image.data[dst] = 206;
            image.data[dst + 1] = 245;
            image.data[dst + 2] = 169;
        } else {
            image.data[dst] = 18;
            image.data[dst + 1] = 29;
            image.data[dst + 2] = 27;
        }
        image.data[dst + 3] = 255;
    }

    ctx.putImageData(image, 0, 0);
}

function fetchVmu(entry) {
    var canvas = document.getElementById(entry.canvas);
    if (!canvas) {
        return;
    }

    fetch("http://localhost:2033/flycast-vmu?slot=" + encodeURIComponent(entry.slot) + "&t=" + Date.now(), {
        cache: "no-store"
    }).then(function(response) {
        if (!response.ok) {
            throw new Error("VMU fetch failed");
        }
        return response.arrayBuffer();
    }).then(function(buffer) {
        var bytes = new Uint8Array(buffer);
        if (bytes.length === 48 * 32) {
            drawVmu(canvas, bytes);
        }
    }).catch(function() {
        drawVmu(canvas, new Uint8Array(48 * 32));
    });
}

function refreshVmus() {
    VMU_SLOTS.forEach(fetchVmu);
}

window.addEventListener("load", function() {
    refreshVmus();
    window.setInterval(refreshVmus, 125);
});
