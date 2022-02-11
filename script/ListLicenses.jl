#=
ListLicenses:
- Julia version: 
- Author: https://discourse.julialang.org/t/i-need-to-do-a-license-compliance-check-on-my-dependencies/50460/3
- Date: 2022-02-11
=#

using DataFrames
using DataFramesMeta
using CSV
using LicenseGrabber
using LicenseCheck

using Pkg
Pkg.activate(".")

license_locations = LicenseGrabber.getlicloc()
license_checks = Dict(
    pkg => filter(nt -> nt.license_file_percent_covered > 0, map(f -> licensecheck(read(f, String)), fs))
    for (pkg, fs) in license_locations
        )
license_approvals = Dict(pkg => all(map(nt -> (length(nt.licenses_found)) > 0 && is_osi_approved(nt), nts)) for (pkg, nts) in license_checks)
packages = collect(keys(license_locations))
licenses = [map(nt -> nt.licenses_found, license_checks[p]) for p in packages]
coverages = [map(nt -> nt.license_file_percent_covered, license_checks[p]) for p in packages]
df = @chain DataFrame(package = packages, license = licenses, coverage = coverages) begin
    flatten([:license, :coverage])
    flatten(:license)

write(df, "licenses.csv")
end