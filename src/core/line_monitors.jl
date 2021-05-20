function get_linenames()
    return _ODSS.Lines.AllNames()
end


function add_line_monitors!()
    for linename in get_linenames()
        _ODSS.dss("""
            New Monitor.monitor_line_$linename  element=Line.$linename
        """)
    end
end


function export_line_monitors!()
    for linename in get_linenames()
        _ODSS.dss("""
            Export Monitor monitor_line_$linename
        """)
    end
end


