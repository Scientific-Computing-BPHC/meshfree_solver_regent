import "regent"
require "limiters"
require "split_fluxes"
require "outer_fluxes" -- for qtilde_to_primitive

local C = regentlib.c
local sqrt = regentlib.sqrt(double)
local pow = regentlib.pow(double)

__demand(__inline)
task interior_dGx_pos(pgp : region(ispace(int1d), Point), idx : int, config : Config)
where 
  reads(pgp.{x, y, nx, ny, xpos_conn, q, dq0, dq1, min_dist, minq, maxq})
do
  var power : int = 0
  var limiter_flag : int = 1

  var sum_delx_sqr : double = 0.0
  var sum_dely_sqr : double = 0.0
  var sum_delx_dely : double = 0.0

  var sum_delx_delf : double[4]
  var sum_dely_delf : double[4]

  for i = 0, 4 do
    sum_delx_delf[i] = 0
    sum_dely_delf[i] = 0
  end

  var x_i = pgp[idx].x
  var y_i = pgp[idx].y

  var nx = pgp[idx].nx
  var ny = pgp[idx].ny

  var tx = ny
  var ty = -nx

  var itm : int
  __demand(__index_launch)
  for i = 0, 20 do
    itm = pgp[idx].xpos_conn[i]
    if itm == 0 then
      break
    else
      var x_k = pgp[itm].x
      var y_k = pgp[itm].y

      var delx = x_k - x_i
      var dely = y_k - y_i
      var dels = delx*tx + dely*ty
      var deln = delx*nx + dely*ny

      var dist = sqrt(dels*dels + deln*deln)
      var weights = pow(dist, power)
    
      var dels_weights = dels*weights
      var deln_weights = deln*weights

      sum_delx_sqr = sum_delx_sqr + dels*dels_weights
      sum_dely_sqr = sum_dely_sqr + deln*deln_weights

      sum_delx_dely = sum_delx_dely + dels*deln_weights
      
      var qtilde_i : double[4]
      var qtilde_k : double[4]
      for i = 0, 4 do
        qtilde_i[i] = pgp[idx].q[i] - 0.5 * (delx * pgp[idx].dq0[i] + dely * pgp[idx].dq1[i])
        qtilde_k[i] = pgp[itm].q[i] - 0.5 * (delx * pgp[itm].dq0[i] + dely * pgp[itm].dq1[i])
      end
            
      var phi_i = venkat_limiter(qtilde_i, pgp, idx, config)
      var phi_k = venkat_limiter(qtilde_k, pgp, itm, config)
      
      for i = 0, 4 do
        qtilde_i[i] = pgp[idx].q[i] - 0.5 * phi_i[i] * (delx * pgp[idx].dq0[i] + dely * pgp[idx].dq1[i])
        qtilde_k[i] = pgp[itm].q[i] - 0.5 * phi_k[i] * (delx * pgp[itm].dq0[i] + dely * pgp[itm].dq1[i])
      end
      
      var result : double[4] = qtilde_to_primitive(qtilde_i, config.gamma)
      var G_i : double[4] = flux_Gxp(nx, ny, result[0], result[1], result[2], result[3])
      result = qtilde_to_primitive(qtilde_k, config.gamma)
      var G_k : double[4] = flux_Gxp(nx, ny, result[0], result[1], result[2], result[3])
      for i = 0, 4 do
        sum_delx_delf[i] = sum_delx_delf[i] + (G_k[i] - G_i[i]) * dels_weights
        sum_dely_delf[i] = sum_dely_delf[i] + (G_k[i] - G_i[i]) * deln_weights
      end  
            
    end
  end

  var det = (sum_delx_sqr * sum_dely_sqr - sum_delx_dely * sum_delx_dely)
  var G : double[4]
  for i = 0, 4 do
    G[i] = (sum_delx_delf[i] * sum_dely_sqr - sum_dely_delf[i] * sum_delx_dely) * (1 / det)
  end
  return G
end

__demand(__inline)
task interior_dGx_neg(pgp : region(ispace(int1d), Point), idx : int, config : Config)
where 
  reads(pgp.{x, y, nx, ny, xneg_conn, q, dq0, dq1, min_dist, minq, maxq})
do
  var power : int = 0
  var limiter_flag : int = 1

  var sum_delx_sqr : double = 0.0
  var sum_dely_sqr : double = 0.0
  var sum_delx_dely : double = 0.0

  var sum_delx_delf : double[4]
  var sum_dely_delf : double[4]

  for i = 0, 4 do
    sum_delx_delf[i] = 0
    sum_dely_delf[i] = 0
  end

  var x_i = pgp[idx].x
  var y_i = pgp[idx].y

  var nx = pgp[idx].nx
  var ny = pgp[idx].ny

  var tx = ny
  var ty = -nx

  var itm : int
  __demand(__index_launch)
  for i = 0, 20 do
    itm = pgp[idx].xneg_conn[i]
    if itm == 0 then
      break
    else
      var x_k = pgp[itm].x
      var y_k = pgp[itm].y

      var delx = x_k - x_i
      var dely = y_k - y_i
      var dels = delx*tx + dely*ty
      var deln = delx*nx + dely*ny

      var dist = sqrt(dels*dels + deln*deln)
      var weights = pow(dist, power)
    
      var dels_weights = dels*weights
      var deln_weights = deln*weights

      sum_delx_sqr = sum_delx_sqr + dels*dels_weights
      sum_dely_sqr = sum_dely_sqr + deln*deln_weights

      sum_delx_dely = sum_delx_dely + dels*deln_weights
      
      var qtilde_i : double[4]
      var qtilde_k : double[4]
      for i = 0, 4 do
        qtilde_i[i] = pgp[idx].q[i] - 0.5 * (delx * pgp[idx].dq0[i] + dely * pgp[idx].dq1[i])
        qtilde_k[i] = pgp[itm].q[i] - 0.5 * (delx * pgp[itm].dq0[i] + dely * pgp[itm].dq1[i])
      end
            
      var phi_i = venkat_limiter(qtilde_i, pgp, idx, config)
      var phi_k = venkat_limiter(qtilde_k, pgp, itm, config)
      
      for i = 0, 4 do
        qtilde_i[i] = pgp[idx].q[i] - 0.5 * phi_i[i] * (delx * pgp[idx].dq0[i] + dely * pgp[idx].dq1[i])
        qtilde_k[i] = pgp[itm].q[i] - 0.5 * phi_k[i] * (delx * pgp[itm].dq0[i] + dely * pgp[itm].dq1[i])
      end
      
      var result : double[4] = qtilde_to_primitive(qtilde_i, config.gamma)
      var G_i : double[4] = flux_Gxn(nx, ny, result[0], result[1], result[2], result[3])
      result = qtilde_to_primitive(qtilde_k, config.gamma)
      var G_k : double[4] = flux_Gxn(nx, ny, result[0], result[1], result[2], result[3])
      for i = 0, 4 do
        sum_delx_delf[i] = sum_delx_delf[i] + (G_k[i] - G_i[i]) * dels_weights
        sum_dely_delf[i] = sum_dely_delf[i] + (G_k[i] - G_i[i]) * deln_weights
      end  
            
    end
  end

  var det = sum_delx_sqr * sum_dely_sqr - sum_delx_dely * sum_delx_dely
  var G : double[4]
  for i = 0, 4 do
    G[i] = (sum_delx_delf[i] * sum_dely_sqr - sum_dely_delf[i] * sum_delx_dely) * (1 / det)
  end
  return G
end

__demand(__inline)
task interior_dGy_pos(pgp : region(ispace(int1d), Point), idx : int, config : Config)
where 
  reads(pgp.{x, y, nx, ny, ypos_conn, q, dq0, dq1, min_dist, minq, maxq})
do
  var power : int = 0
  var limiter_flag : int = 1

  var sum_delx_sqr : double = 0.0
  var sum_dely_sqr : double = 0.0
  var sum_delx_dely : double = 0.0

  var sum_delx_delf : double[4]
  var sum_dely_delf : double[4]

  for i = 0, 4 do
    sum_delx_delf[i] = 0
    sum_dely_delf[i] = 0
  end

  var x_i = pgp[idx].x
  var y_i = pgp[idx].y

  var nx = pgp[idx].nx
  var ny = pgp[idx].ny

  var tx = ny
  var ty = -nx

  var itm : int
  __demand(__index_launch)
  for i = 0, 20 do
    itm = pgp[idx].ypos_conn[i]
    if itm == 0 then
      break
    else
      var x_k = pgp[itm].x
      var y_k = pgp[itm].y

      var delx = x_k - x_i
      var dely = y_k - y_i
      var dels = delx*tx + dely*ty
      var deln = delx*nx + dely*ny

      var dist = sqrt(dels*dels + deln*deln)
      var weights = pow(dist, power)
    
      var dels_weights = dels*weights
      var deln_weights = deln*weights

      sum_delx_sqr = sum_delx_sqr + dels*dels_weights
      sum_dely_sqr = sum_dely_sqr + deln*deln_weights

      sum_delx_dely = sum_delx_dely + dels*deln_weights
      
      var qtilde_i : double[4]
      var qtilde_k : double[4]
      for i = 0, 4 do
        qtilde_i[i] = pgp[idx].q[i] - 0.5 * (delx * pgp[idx].dq0[i] + dely * pgp[idx].dq1[i])
        qtilde_k[i] = pgp[itm].q[i] - 0.5 * (delx * pgp[itm].dq0[i] + dely * pgp[itm].dq1[i])
      end
            
      var phi_i = venkat_limiter(qtilde_i, pgp, idx, config)
      var phi_k = venkat_limiter(qtilde_k, pgp, itm, config)
      
      for i = 0, 4 do
        qtilde_i[i] = pgp[idx].q[i] - 0.5 * phi_i[i] * (delx * pgp[idx].dq0[i] + dely * pgp[idx].dq1[i])
        qtilde_k[i] = pgp[itm].q[i] - 0.5 * phi_k[i] * (delx * pgp[itm].dq0[i] + dely * pgp[itm].dq1[i])
      end
      
      var result : double[4] = qtilde_to_primitive(qtilde_i, config.gamma)
      var G_i : double[4] = flux_Gyp(nx, ny, result[0], result[1], result[2], result[3])
      result = qtilde_to_primitive(qtilde_k, config.gamma)
      var G_k : double[4] = flux_Gyp(nx, ny, result[0], result[1], result[2], result[3])
      for i = 0, 4 do
        sum_delx_delf[i] = sum_delx_delf[i] + (G_k[i] - G_i[i]) * dels_weights
        sum_dely_delf[i] = sum_dely_delf[i] + (G_k[i] - G_i[i]) * deln_weights
      end  
            
    end
  end

  var det = sum_delx_sqr * sum_dely_sqr - sum_delx_dely * sum_delx_dely
  var G : double[4]
  for i = 0, 4 do
    G[i] = (sum_dely_delf[i] * sum_delx_sqr - sum_delx_delf[i] * sum_delx_dely) * (1 / det)
  end
  return G
end

__demand(__inline)
task interior_dGy_neg(pgp : region(ispace(int1d), Point), idx : int, config : Config)
where 
  reads(pgp.{x, y, nx, ny, yneg_conn, q, dq0, dq1, min_dist, minq, maxq})
do
  var power : int = 0
  var limiter_flag : int = 1

  var sum_delx_sqr : double = 0.0
  var sum_dely_sqr : double = 0.0
  var sum_delx_dely : double = 0.0

  var sum_delx_delf : double[4]
  var sum_dely_delf : double[4]

  for i = 0, 4 do
    sum_delx_delf[i] = 0
    sum_dely_delf[i] = 0
  end

  var x_i = pgp[idx].x
  var y_i = pgp[idx].y

  var nx = pgp[idx].nx
  var ny = pgp[idx].ny

  var tx = ny
  var ty = -nx

  var itm : int
  __demand(__index_launch)
  for i = 0, 20 do
    itm = pgp[idx].yneg_conn[i]
    if itm == 0 then
      break
    else
      var x_k = pgp[itm].x
      var y_k = pgp[itm].y

      var delx = x_k - x_i
      var dely = y_k - y_i
      var dels = delx*tx + dely*ty
      var deln = delx*nx + dely*ny

      var dist = sqrt(dels*dels + deln*deln)
      var weights = pow(dist, power)
    
      var dels_weights = dels*weights
      var deln_weights = deln*weights

      sum_delx_sqr = sum_delx_sqr + dels*dels_weights
      sum_dely_sqr = sum_dely_sqr + deln*deln_weights

      sum_delx_dely = sum_delx_dely + dels*deln_weights
      
      var qtilde_i : double[4]
      var qtilde_k : double[4]
      for i = 0, 4 do
        qtilde_i[i] = pgp[idx].q[i] - 0.5 * (delx * pgp[idx].dq0[i] + dely * pgp[idx].dq1[i])
        qtilde_k[i] = pgp[itm].q[i] - 0.5 * (delx * pgp[itm].dq0[i] + dely * pgp[itm].dq1[i])
      end
            
      var phi_i = venkat_limiter(qtilde_i, pgp, idx, config)
      var phi_k = venkat_limiter(qtilde_k, pgp, itm, config)
      
      for i = 0, 4 do
        qtilde_i[i] = pgp[idx].q[i] - 0.5 * phi_i[i] * (delx * pgp[idx].dq0[i] + dely * pgp[idx].dq1[i])
        qtilde_k[i] = pgp[itm].q[i] - 0.5 * phi_k[i] * (delx * pgp[itm].dq0[i] + dely * pgp[itm].dq1[i])
      end
      
      var result : double[4] = qtilde_to_primitive(qtilde_i, config.gamma)
      var G_i : double[4] = flux_Gyn(nx, ny, result[0], result[1], result[2], result[3])
      result = qtilde_to_primitive(qtilde_k, config.gamma)
      var G_k : double[4] = flux_Gyn(nx, ny, result[0], result[1], result[2], result[3])
      for i = 0, 4 do
        sum_delx_delf[i] = sum_delx_delf[i] + (G_k[i] - G_i[i]) * dels_weights
        sum_dely_delf[i] = sum_dely_delf[i] + (G_k[i] - G_i[i]) * deln_weights
      end  
            
    end
  end

  var det = sum_delx_sqr * sum_dely_sqr - sum_delx_dely * sum_delx_dely
  var G : double[4]
  for i = 0, 4 do
    G[i] = (sum_dely_delf[i] * sum_delx_sqr - sum_delx_delf[i] * sum_delx_dely) * (1 / det)
  end
  return G
end
