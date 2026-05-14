function setStatus(message) {
    var status = document.getElementById("status");
    if(status) {
        status.textContent = message || "";
    }
}

function clearStatusLater() {
    window.setTimeout(function() {
        setStatus("");
    }, 1600);
}

function runJson(endpoint, okText, failText) {
    setStatus(okText + "...");
    return fetch("http://localhost:2033/" + endpoint)
        .then(function(response) {
            return response.json();
        })
        .then(function(result) {
            setStatus(result && result.ok ? okText : (failText || "Failed"));
            return result;
        })
        .catch(function() {
            setStatus(failText || "Failed");
        })
        .finally(clearStatusLater);
}

function runHotkey(action) {
    var labels = {
        "save-state": "Save",
        "load-state": "Load",
        "slot-previous": "Slot -",
        "slot-next": "Slot +",
        "menu": "Menu",
        "screenshot": "Shot",
        "rewind": "Rewind",
        "fast-forward": "Fast Fwd"
    };
    return runJson("hotkey?action=" + encodeURIComponent(action), labels[action] || "Sent", "Failed");
}

function bindButton(button, handler) {
    var lastRun = 0;
    var run = function(event) {
        if(event) {
            event.preventDefault();
            event.stopPropagation();
        }

        var now = Date.now();
        if(now - lastRun < 450) {
            return;
        }
        lastRun = now;

        button.disabled = true;
        Promise.resolve(handler()).finally(function() {
            window.setTimeout(function() {
                button.disabled = false;
            }, 180);
        });
    };

    button.addEventListener("click", run);
    button.addEventListener("pointerup", run);
    button.addEventListener("touchend", run, { passive: false });
}

function achievementEarned(achievement) {
    return Boolean(achievement && (achievement.DateEarned || achievement.DateEarnedHardcore));
}

function achievementHardcore(achievement) {
    return Boolean(achievement && achievement.DateEarnedHardcore);
}

function achievementPoints(achievement) {
    var points = parseInt(achievement && achievement.Points, 10);
    return isNaN(points) ? 0 : points;
}

function clearCheevosList(message) {
    var list = document.getElementById("cheevos-list");
    if(list) {
        list.innerHTML = "";
        var empty = document.createElement("div");
        empty.className = "cheevos-empty";
        empty.textContent = message;
        list.appendChild(empty);
    }
}

function renderCheevos(data) {
    var heading = document.getElementById("cheevos-heading");
    var summary = document.getElementById("cheevos-summary");
    var list = document.getElementById("cheevos-list");

    if(!list) {
        return;
    }

    if(!data || !data.ok) {
        if(heading) {
            heading.textContent = "Achievements";
        }
        if(summary) {
            summary.textContent = "";
        }
        clearCheevosList((data && data.message) || "No achievement data");
        return;
    }

    var achievements = data.Achievements || [];
    var earned = 0;
    var hardcore = 0;
    var earnedPoints = 0;
    var totalPoints = 0;

    achievements.forEach(function(achievement) {
        var points = achievementPoints(achievement);
        totalPoints += points;
        if(achievementEarned(achievement)) {
            earned += 1;
            earnedPoints += points;
        }
        if(achievementHardcore(achievement)) {
            hardcore += 1;
        }
    });

    if(heading) {
        heading.textContent = data.Title || (data.game && data.game.name) || "Achievements";
    }

    if(summary) {
        var percent = achievements.length ? Math.round((earned * 100) / achievements.length) : 0;
        summary.textContent = earned + "/" + achievements.length + " softcore  |  " +
            hardcore + "/" + achievements.length + " hardcore  |  " +
            earnedPoints + "/" + totalPoints + " pts  |  " + percent + "%";
    }

    list.innerHTML = "";
    if(!achievements.length) {
        clearCheevosList("No achievements for current game");
        return;
    }

    achievements.forEach(function(achievement) {
        var row = document.createElement("article");
        row.className = "cheevo-row" + (achievementEarned(achievement) ? " earned" : " locked");

        var badge = document.createElement("img");
        badge.className = "cheevo-badge";
        badge.alt = "";
        badge.src = "http://localhost:2033/cheevos-badge?name=" +
            encodeURIComponent(achievement.BadgeName || "") +
            "&locked=" + (achievementEarned(achievement) ? "0" : "1");

        var body = document.createElement("div");
        body.className = "cheevo-body";

        var title = document.createElement("div");
        title.className = "cheevo-title";
        title.textContent = achievement.Title || "Achievement";

        var desc = document.createElement("div");
        desc.className = "cheevo-desc";
        desc.textContent = achievement.Description || "";

        var meta = document.createElement("div");
        meta.className = "cheevo-meta";
        meta.textContent = achievementPoints(achievement) + " pts" +
            (achievementHardcore(achievement) ? "  |  hardcore" :
                (achievementEarned(achievement) ? "  |  earned" : ""));

        body.appendChild(title);
        body.appendChild(desc);
        body.appendChild(meta);
        row.appendChild(badge);
        row.appendChild(body);
        list.appendChild(row);
    });
}

function showCheevos() {
    var overlay = document.getElementById("cheevos-overlay");
    if(!overlay) {
        return Promise.resolve();
    }

    overlay.classList.remove("hidden");
    overlay.setAttribute("aria-hidden", "false");
    clearCheevosList("Loading...");
    setStatus("Loading cheevos...");

    return fetch("http://localhost:2033/cheevos-current")
        .then(function(response) {
            return response.json();
        })
        .then(function(data) {
            renderCheevos(data);
            setStatus(data && data.ok ? "Cheevos" : ((data && data.message) || "Failed"));
        })
        .catch(function() {
            clearCheevosList("Failed to load achievements");
            setStatus("Failed");
        })
        .finally(clearStatusLater);
}

function hideCheevos() {
    var overlay = document.getElementById("cheevos-overlay");
    if(overlay) {
        overlay.classList.add("hidden");
        overlay.setAttribute("aria-hidden", "true");
    }
}

function initControls() {
    Array.prototype.forEach.call(document.querySelectorAll("button[data-hotkey]"), function(button) {
        bindButton(button, function() {
            return runHotkey(button.getAttribute("data-hotkey"));
        });
    });

    var topShot = document.getElementById("top-shot");
    if(topShot) {
        bindButton(topShot, function() {
            return runJson("screenshot?target=top", "Saved", "Failed");
        });
    }

    var recordStart = document.getElementById("record-start");
    if(recordStart) {
        bindButton(recordStart, function() {
            return runJson("record-start", "Recording", "Failed");
        });
    }

    var recordStop = document.getElementById("record-stop");
    if(recordStop) {
        bindButton(recordStop, function() {
            return runJson("record-stop", "Stopped", "Failed");
        });
    }

    var forceKill = document.getElementById("force-kill");
    if(forceKill) {
        bindButton(forceKill, function() {
            return runJson("emukill", "Killed", "Failed");
        });
    }

}

window.addEventListener("load", initControls);
