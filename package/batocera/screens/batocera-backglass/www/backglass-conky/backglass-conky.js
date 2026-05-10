var currentSystem = {};
var currentGame = {};
var currentStats = {};
var graphHistory = {
    cpu: [],
    gpu: []
};
var graphSize = 60;

function text(value, fallback) {
    if(value === undefined || value === null || value === "") {
        return fallback || "";
    }
    return String(value);
}

function escapeHtml(value) {
    return text(value, "").replace(/[&<>"']/g, function(match) {
        return {
            "&": "&amp;",
            "<": "&lt;",
            ">": "&gt;",
            "\"": "&quot;",
            "'": "&#039;"
        }[match];
    });
}

function percent(value) {
    if(value === undefined || value === null || isNaN(value)) {
        return 0;
    }
    return Math.max(0, Math.min(100, Number(value)));
}

function setText(id, value) {
    var node = document.getElementById(id);
    if(node) {
        node.textContent = text(value, "--");
    }
}

function setBar(id, value) {
    var node = document.getElementById(id);
    if(node) {
        node.style.width = percent(value) + "%";
    }
}

function formatPercent(value) {
    if(value === undefined || value === null || isNaN(value)) {
        return "--";
    }
    return Math.round(percent(value)) + "%";
}

function pushHistory(name, value) {
    if(value === undefined || value === null || isNaN(value)) {
        return;
    }
    graphHistory[name].push(percent(value));
    while(graphHistory[name].length > graphSize) {
        graphHistory[name].shift();
    }
}

function renderGraph(name, valueId, lineId) {
    var history = graphHistory[name];
    setText(valueId, history.length ? formatPercent(history[history.length - 1]) : "--");

    var line = document.getElementById(lineId);
    if(!line) {
        return;
    }
    if(history.length === 0) {
        line.setAttribute("points", "");
        return;
    }

    var maxIndex = Math.max(graphSize - 1, 1);
    var points = history.map(function(value, index) {
        var x = (index / maxIndex) * 120;
        var y = 36 - ((percent(value) / 100) * 34) - 1;
        return x.toFixed(1) + "," + y.toFixed(1);
    });
    line.setAttribute("points", points.join(" "));
}

function formatUptime(seconds) {
    seconds = Number(seconds || 0);
    var hours = Math.floor(seconds / 3600);
    var minutes = Math.floor((seconds % 3600) / 60);
    if(hours > 0) {
        return hours + "h " + minutes + "m";
    }
    return minutes + "m";
}

function renderSystem() {
    var name = currentSystem.fullname || currentSystem.name || "Batocera";
    setText("system-name", name);

    if(currentSystem.logo) {
        document.getElementById("system-logo").innerHTML = "<img src=\"" + escapeHtml(currentSystem.logo) + "\"/>";
    } else {
        document.getElementById("system-logo").innerHTML = "";
    }
}

function renderGame() {
    var title = currentGame.name || "Select a game";
    setText("game-title", title);

    var meta = [];
    if(currentGame.developer) {
        meta.push(currentGame.developer);
    }
    if(currentGame.releasedate) {
        meta.push(String(currentGame.releasedate).substring(0, 4));
    }
    if(currentGame.genre) {
        meta.push(currentGame.genre);
    }
    setText("game-meta", meta.join(" | "));
    setText("game-desc", currentGame.desc || "");

    var art = currentGame.boxart || currentGame.image || currentGame.fanart || currentGame.thumbnail || "";
    var artNode = document.getElementById("game-art");
    if(art) {
        artNode.className = "";
        artNode.innerHTML = "<img src=\"" + escapeHtml(art) + "\"/>";
    } else {
        artNode.className = "empty";
        artNode.innerHTML = "";
    }
}

function renderStats() {
    setText("model-name", currentStats.model || "");
    setText("clock-time", currentStats.time || "--:--");
    setText("clock-date", currentStats.date || "");

    var cpuPercent = currentStats.cpu ? currentStats.cpu.percent : null;
    var gpuPercent = currentStats.gpu ? currentStats.gpu.percent : null;
    pushHistory("cpu", cpuPercent);
    pushHistory("gpu", gpuPercent);
    renderGraph("cpu", "cpu-graph-value", "cpu-graph-line");
    renderGraph("gpu", "gpu-graph-value", "gpu-graph-line");

    if(cpuPercent !== undefined && cpuPercent !== null) {
        setText("cpu-value", formatPercent(cpuPercent));
        setBar("cpu-bar", cpuPercent);
    } else {
        setText("cpu-value", "--");
        setBar("cpu-bar", 0);
    }
    if(currentStats.cpu_temp_c !== undefined && currentStats.cpu_temp_c !== null) {
        setText("cpu-temp", currentStats.cpu_temp_c + " C");
    } else {
        setText("cpu-temp", "");
    }

    if(gpuPercent !== undefined && gpuPercent !== null) {
        setText("gpu-value", formatPercent(gpuPercent));
        setBar("gpu-bar", gpuPercent);
    } else {
        setText("gpu-value", "--");
        setBar("gpu-bar", 0);
    }
    if(currentStats.gpu && currentStats.gpu.mhz) {
        setText("gpu-sub", currentStats.gpu.mhz + " / " + currentStats.gpu.max_mhz + " MHz");
    } else if(currentStats.gpu && currentStats.gpu.source) {
        setText("gpu-sub", currentStats.gpu.source);
    } else {
        setText("gpu-sub", "");
    }

    if(currentStats.fan && currentStats.fan.available) {
        if(currentStats.fan.rpm !== undefined && currentStats.fan.rpm !== null) {
            setText("fan-value", currentStats.fan.rpm + " RPM");
        } else {
            setText("fan-value", formatPercent(currentStats.fan.percent));
        }
        var fanSub = [];
        if(currentStats.fan.percent !== undefined && currentStats.fan.percent !== null) {
            fanSub.push(formatPercent(currentStats.fan.percent));
        }
        if(currentStats.fan.mode) {
            fanSub.push(currentStats.fan.mode);
        }
        setText("fan-sub", fanSub.join(" "));
        setBar("fan-bar", currentStats.fan.percent);
    } else {
        setText("fan-value", "--");
        setText("fan-sub", "");
        setBar("fan-bar", 0);
    }

    if(currentStats.load && currentStats.load.length > 0) {
        setText("load-value", currentStats.load[0]);
    } else {
        setText("load-value", "--");
    }
    setText("uptime-value", "Up " + formatUptime(currentStats.uptime_seconds));

    if(currentStats.memory) {
        setText("memory-value", currentStats.memory.percent + "%");
        setBar("memory-bar", currentStats.memory.percent);
    }

    if(currentStats.userdata) {
        setText("storage-value", currentStats.userdata.percent + "%");
        setBar("storage-bar", currentStats.userdata.percent);
    }

    if(currentStats.battery && currentStats.battery.percent !== null && currentStats.battery.percent !== undefined) {
        setText("battery-value", currentStats.battery.percent + "%");
        setText("battery-status", currentStats.battery.status || "");
    } else {
        setText("battery-value", "--");
        setText("battery-status", "");
    }

    if(currentStats.brightness !== undefined && currentStats.brightness !== null) {
        setText("brightness-value", currentStats.brightness + "%");
        setBar("brightness-bar", currentStats.brightness);
    } else {
        setText("brightness-value", "--");
        setBar("brightness-bar", 0);
    }
}

function renderAll() {
    renderSystem();
    renderGame();
    renderStats();
}

function onSystem(infos) {
    currentSystem = infos || {};
    renderAll();
}

function onGame(infos) {
    currentGame = infos || {};
    renderAll();
}

function pollStats() {
    fetch("http://localhost:2033/stats")
        .then(function(response) {
            return response.json();
        })
        .then(function(stats) {
            currentStats = stats || {};
            renderAll();
        })
        .catch(function() {
        });
}

function takeTopScreenshot() {
    var button = document.getElementById("screenshot-top");
    var status = document.getElementById("screenshot-status");
    if(button) {
        button.disabled = true;
    }
    if(status) {
        status.textContent = "Saving...";
    }

    fetch("http://localhost:2033/screenshot?target=top")
        .then(function(response) {
            return response.json();
        })
        .then(function(result) {
            if(status) {
                status.textContent = result && result.ok ? "Saved" : "Failed";
            }
        })
        .catch(function() {
            if(status) {
                status.textContent = "Failed";
            }
        })
        .finally(function() {
            if(button) {
                button.disabled = false;
            }
            window.setTimeout(function() {
                if(status) {
                    status.textContent = "";
                }
            }, 1800);
        });
}

function setActionStatus(message) {
    var status = document.getElementById("screenshot-status");
    if(status) {
        status.textContent = message;
    }
}

function clearActionStatusLater() {
    window.setTimeout(function() {
        setActionStatus("");
    }, 1800);
}

function toggleButton(id, disabled) {
    var button = document.getElementById(id);
    if(button) {
        button.disabled = disabled;
    }
}

function runBackglassAction(buttonId, endpoint, busyText, successText) {
    toggleButton(buttonId, true);
    setActionStatus(busyText);

    fetch("http://localhost:2033/" + endpoint)
        .then(function(response) {
            return response.json();
        })
        .then(function(result) {
            setActionStatus(result && result.ok ? successText : "Failed");
        })
        .catch(function() {
            setActionStatus("Failed");
        })
        .finally(function() {
            toggleButton(buttonId, false);
            clearActionStatusLater();
        });
}

function startRecording() {
    runBackglassAction("record-start", "record-start", "Starting...", "Recording");
}

function stopRecording() {
    runBackglassAction("record-stop", "record-stop", "Stopping...", "Stopped");
}

function forceKillEmulator() {
    var button = document.getElementById("force-kill");
    var status = document.getElementById("screenshot-status");
    if(button) {
        button.disabled = true;
    }
    if(status) {
        status.textContent = "Killing...";
    }

    fetch("http://localhost:2033/emukill")
        .then(function(response) {
            return response.json();
        })
        .then(function(result) {
            if(status) {
                if(result && result.ok) {
                    status.textContent = "Killed";
                } else if(result && result.code === 21) {
                    status.textContent = "No game";
                } else {
                    status.textContent = "Failed";
                }
            }
        })
        .catch(function() {
            if(status) {
                status.textContent = "Failed";
            }
        })
        .finally(function() {
            if(button) {
                button.disabled = false;
            }
            window.setTimeout(function() {
                if(status) {
                    status.textContent = "";
                }
            }, 1800);
        });
}

window.onload = function() {
    renderAll();
    pollStats();
    setInterval(pollStats, 1000);

    var screenshotButton = document.getElementById("screenshot-top");
    if(screenshotButton) {
        screenshotButton.addEventListener("click", takeTopScreenshot);
    }

    var killButton = document.getElementById("force-kill");
    if(killButton) {
        killButton.addEventListener("click", forceKillEmulator);
    }

    var recordStartButton = document.getElementById("record-start");
    if(recordStartButton) {
        recordStartButton.addEventListener("click", startRecording);
    }

    var recordStopButton = document.getElementById("record-stop");
    if(recordStopButton) {
        recordStopButton.addEventListener("click", stopRecording);
    }
};
