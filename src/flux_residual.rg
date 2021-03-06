import "regent"
require "config"
require "point"
require "outer_fluxes"
require "wall_fluxes"
require "interior_fluxes"

local C = regentlib.c

terra pprint(a : double[4])
  C.printf("[\x1b[33m %0.15lf, %0.15lf, %0.15lf, %0.15lf]\n \x1b[0m", a[0], a[1], a[2], a[3])
end

__demand(__cuda)
task cal_flux_residual(pe : region(ispace(int1d), Point),
           pn : region(ispace(int1d), Point), config : Config)
where 
  reads(pe.{flag_1, localID, delta}, 
        pn.{x, y, nx, ny, q, dq0, dq1, xpos_conn, xneg_conn, ypos_conn, 
        yneg_conn, min_dist, minq, maxq}),
  writes(pe.flux_res)
do
  __demand(__openmp)
  for point in pe do
    if point.flag_1 == 0 then
      var Gxp = wall_dGx_pos(pn, point.localID, config)
      var Gxn = wall_dGx_neg(pn, point.localID, config)
      var Gyn = wall_dGy_neg(pn, point.localID, config)

      var d = 2.0 * point.delta
      var GTemp = array(d, d, d, d) * (Gxp + Gxn + Gyn)
      point.flux_res = GTemp
    end
    if point.flag_1 == 1 then
      var Gxp = interior_dGx_pos(pn, point.localID, config)
      var Gxn = interior_dGx_neg(pn, point.localID, config)
      var Gyp = interior_dGy_pos(pn, point.localID, config)
      var Gyn = interior_dGy_neg(pn, point.localID, config)

      var d = point.delta
      var GTemp = array(d, d, d, d) * (Gxp + Gxn + Gyp + Gyn)
      point.flux_res = GTemp
    end
    if point.flag_1 == 2 then
      var Gxp = outer_dGx_pos(pn, point.localID, config)
      var Gxn = outer_dGx_neg(pn, point.localID, config)
      var Gyp = outer_dGy_pos(pn, point.localID, config)

      var d = point.delta
      var GTemp = array(d, d, d, d) * (Gxp + Gxn + Gyp)
      point.flux_res = GTemp
    end
  end
end
