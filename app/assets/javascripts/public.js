$(document).ready(function () {
    $('a').tooltip();
});
$(document).ready(function () {
    $('i').tooltip();
});


function createAudioRecordingCalendar() {

    // create formatters and global magic numbers
    var day = d3.time.format("%w"),
        week = d3.time.format("%U"),
        format = d3.time.format("%Y-%m-%d"),
        month_format = d3.time.format("%b"),
        width = 960,
        height = 136,
        cellSize = 17, // cell size
        firstYear = null, //new Date().getFullYear(),
        lastYear = null, //2007
        colourDomain = [0, 100],//domain is input values, usually x
        colourRangeStart = 0, // range is output values, usually y
        colourRangeStop = 10,
        colourRangeStep = 1,
        defaultSelection = [
            {name: '-- Everything --', id: null}
        ]
        ;

    // set scale for colours
    var color = d3.scale.quantize()
        .domain(colourDomain)
        .range(d3.range(colourRangeStart, colourRangeStop, colourRangeStep).map(function (d) {
            return d > 0 ? 'q9-11' : '';
        }));

    d3.select('#update_calendar')
        .on('click', function () {
            var project_id_el = document.getElementById('project_list');
            var site_id_el = document.getElementById('site_list');

            var url = window.location.origin + window.location.pathname + '?';
            if (project_id_el.selectedIndex > 0) {
                var project_id = project_id_el.options[project_id_el.selectedIndex].value;
                url += 'project_id=' + project_id;
            }
            if (site_id_el.selectedIndex > 0) {
                var site_id = site_id_el.options[site_id_el.selectedIndex].value;
                url += '&site_id=' + site_id;
            }

            window.location = url;
        });

    // download json to get data
    d3.json("/audio_recording_catalogue.json", function (error, json) {

        var data = d3.nest()
            .key(function (d) {
                return d.extracted_year + "-" + d.extracted_month + "-" + d.extracted_day;
            })
            .rollup(function (d) {
                var itemYear = parseInt(d[0].extracted_year);
                if (firstYear == null || itemYear > firstYear) {
                    firstYear = itemYear;
                }
                if (lastYear == null || itemYear < lastYear) {
                    lastYear = itemYear;
                }

                var itemCount = parseInt(d[0].count);
                if (colourRangeStop == null || itemCount > colourRangeStop) {
                    colourRangeStop = itemCount;
                }

                return itemCount;
            })
            .map(json);

        var elements = createSvgCalendarView(firstYear, lastYear);
        addDataToCalendar(elements.rect, data)
    });

    d3.select('#audioRecordingCalendar').style("height", "2910px");

    // get project list
    d3.json("/projects.json", function (error, json) {
        d3.select('#project_list')
            .on('change', function () {
                var selectedValue = this.options[this.selectedIndex].value;
                if (selectedValue != null) {
                    updateSiteList(selectedValue);
                } else {
                    d3.select('#site_list')
                        .selectAll('option')
                        .remove();
                }
            })
            .selectAll('option')
            .data(defaultSelection.concat(json))
            .enter()
            .append('option')
            .attr('value', function (d) {
                return d.id
            })
            .text(function (d) {
                return d.name;
            });
    });

    function updateSiteList(projectId) {
        var url = "/projects/" + projectId + "/sites.json";
        d3.json(url, function (error, json) {
            d3.select('#site_list')
                .selectAll('option')
                .remove()
                .data(defaultSelection.concat(json))
                .enter()
                .append('option')
                .attr('value', function (d) {
                    return d.id
                })
                .text(function (d) {
                    return d.name;
                });
        });
    }


    function addDataToCalendar(rect, data) {
        rect.filter(function (d) {
            return d in data;
        })
            .attr("class", function (d) {
                return "day " + color(data[d]);
            })
            .select("title")
            .text(function (d) {
                return d + ": " + data[d] + " audio recordings";
            });
    }

    function createSvgCalendarView(firstYear, lastYear) {

        // create svg and year rows
        var svg = d3.select("#audioRecordingCalendar").selectAll("svg")
            .data(d3.range(firstYear, lastYear - 1, -1)) // subtract one due to exclusive end bound
            .enter().append("svg")
            .attr("width", width)
            .attr("height", height)
            .attr("class", "RdYlGn")
            .append("g")
            .attr("transform", "translate(" + ((width - cellSize * 53) / 2) + "," + (height - cellSize * 7 - 1) + ")");

        // add year label to left end
        svg.append("text")
            .attr("transform", "translate(-6," + cellSize * 3.5 + ")rotate(-90)")
            .style("text-anchor", "middle")
            .text(function (d) {
                return d;
            });

        // create day rectangles
        var rect = svg.selectAll(".day")
            .data(function (d) {
                return d3.time.days(new Date(d, 0, 1), new Date(d + 1, 0, 1));
            })
            .enter().append("rect")
            .attr("class", "day")
            .attr("width", cellSize)
            .attr("height", cellSize)
            .attr("x", function (d) {
                return week(d) * cellSize;
            })
            .attr("y", function (d) {
                return day(d) * cellSize;
            })
            .datum(format);

        // add titles to day rectangles
        rect.append("title")
            .text(function (d) {
                return d;
            });

        // find the months and outline them
        var month = svg.selectAll(".month")
            .data(function (d) {
                return d3.time.months(new Date(d, 0, 1), new Date(d + 1, 0, 1));
            })
            .enter().append("path")
            .attr("class", "month")
            .attr("d", monthPath);

        // add labels for each month
        svg.selectAll(".monthText")
            .data(function (d) {
                return d3.time.months(new Date(d, 0, 1), new Date(d + 1, 0, 1));
            })
            .enter()
            .append("text")
            .attr("x", function (d) {
                return (week(d) * cellSize) + (cellSize * 2.8);
            })
            .attr("y", function (d) {
                return -2.5;
            })
            .style("text-anchor", "middle")
            .text(function (d) {
                return month_format(d);
            });

        return {
            svg: svg,
            day: day,
            month: month,
            rect: rect
        };
    }

    // calculate the path to surround the days of the month
    function monthPath(t0) {
        var t1 = new Date(t0.getFullYear(), t0.getMonth() + 1, 0),
            d0 = +day(t0), w0 = +week(t0),
            d1 = +day(t1), w1 = +week(t1);
        return "M" + (w0 + 1) * cellSize + "," + d0 * cellSize
            + "H" + w0 * cellSize + "V" + 7 * cellSize
            + "H" + w1 * cellSize + "V" + (d1 + 1) * cellSize
            + "H" + (w1 + 1) * cellSize + "V" + 0
            + "H" + (w0 + 1) * cellSize + "Z";
    }
}