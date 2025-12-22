pragma Singleton

import QtQuick

QtObject {
    function parse(dateStr) {
        if (!dateStr)
            return null;

        try {
            var s = String(dateStr);

            // Taskwarrior timestamps: YYYYMMDDTHHMMSSZ (UTC) or without Z.
            if (s.length >= 15 && s.indexOf("T") !== -1) {
                var year = s.substring(0, 4);
                var month = s.substring(4, 6);
                var day = s.substring(6, 8);
                var hour = s.substring(9, 11);
                var minute = s.substring(11, 13);
                var second = s.substring(13, 15);
                var hasZ = s.endsWith("Z");
                var iso = year + "-" + month + "-" + day + "T" + hour + ":" + minute + ":" + second + (hasZ ? "Z" : "");
                var dt = new Date(iso);
                if (!isNaN(dt.getTime()))
                    return dt;
            }

            // Date-only: YYYYMMDD
            if (s.length >= 8 && s.indexOf("-") === -1) {
                var y = parseInt(s.substring(0, 4));
                var m = parseInt(s.substring(4, 6)) - 1;
                var d = parseInt(s.substring(6, 8));
                var dLocal = new Date(y, m, d);
                if (!isNaN(dLocal.getTime()))
                    return dLocal;
            }

            // User input: YYYY-MM-DD (treat as local date)
            if (s.length >= 10 && s.charAt(4) === "-" && s.charAt(7) === "-") {
                var y2 = parseInt(s.substring(0, 4));
                var m2 = parseInt(s.substring(5, 7)) - 1;
                var d2 = parseInt(s.substring(8, 10));
                var dLocal2 = new Date(y2, m2, d2);
                if (!isNaN(dLocal2.getTime()))
                    return dLocal2;
            }

            var fallback = new Date(s);
            if (!isNaN(fallback.getTime()))
                return fallback;
        } catch (e) {}

        return null;
    }

    function startOfLocalDay(dt) {
        if (!dt)
            return null;
        var d = new Date(dt);
        d.setHours(0, 0, 0, 0);
        return d;
    }

    function isSameLocalDay(a, b) {
        if (!a || !b)
            return false;
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    function isToday(dateStr) {
        var dt = parse(dateStr);
        if (!dt)
            return false;
        var now = new Date();
        return isSameLocalDay(dt, now);
    }

    function isFutureDay(dateStr) {
        var dt = parse(dateStr);
        if (!dt)
            return false;
        var today = new Date();
        today.setHours(0, 0, 0, 0);
        var day = startOfLocalDay(dt);
        return day > today;
    }

    function isPastDay(dateStr) {
        var dt = parse(dateStr);
        if (!dt)
            return false;
        var today = new Date();
        today.setHours(0, 0, 0, 0);
        var day = startOfLocalDay(dt);
        return day < today;
    }
}
