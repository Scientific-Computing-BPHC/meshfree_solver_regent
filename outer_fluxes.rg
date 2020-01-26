import "regent"
require "point"
require "limiters"
require "quadrant_fluxes"

local C = regentlib.c
local Cmath = terralib.includec("math.h")

task qtilde_to_primitive(qtilde : double[4])
        var gamma : double = 1.4

        var q1 = qtilde[0]
        var q2 = qtilde[1]
        var q3 = qtilde[2]
        var q4 = qtilde[3]

        var beta = -q4 * 0.5
        var temp = 0.5 / beta

        var u1 = q2 * temp
        var u2 = q3 * temp

        var temp1 = q1 + beta * (u1*u1 + u2*u2)
        var temp2 = temp1 - (Cmath.log(beta)/(gamma - 1))
        var rho = Cmath.exp(temp2)
        var pr = rho * temp

        var arr : double[4]
        arr[0] = u1
        arr[1] = u2
        arr[2] = rho
        arr[3] = pr

        return arr
end

task outer_dGx_pos(globaldata : region(ispace(int1d), Point), idx : int)
where 
	reads(globaldata.{x, y, nx, ny, xpos_conn, q, dq, minq, maxq, min_dist})
do
	var power : int = 0
	var limiter_flag : int = 1

	var sum_delx_sqr : double = 0
    	var sum_dely_sqr : double = 0
    	var sum_delx_dely : double = 0

	var sum_delx_delf : double[4]
	var sum_dely_delf : double[4]

	for i = 0, 4 do
		sum_delx_delf[i] = 0
		sum_dely_delf[i] = 0
	end

	var x_i = globaldata[idx].x
	var y_i = globaldata[idx].y

	var nx = globaldata[idx].nx
	var ny = globaldata[idx].ny

	var tx = ny
	var ty = -nx

	var itm : int
	for i = 0, 20 do
		itm = globaldata[idx].xpos_conn[i]
		if itm == 0 then
			break
		else
			var x_k = globaldata[itm].x
        		var y_k = globaldata[itm].y

        		var delx = x_k - x_i
        		var dely = y_k - y_i
        		var dels = delx*tx + dely*ty
        		var deln = delx*nx + dely*ny

			var dist = Cmath.sqrt(dels*dels + deln*deln)
        		var weights = Cmath.pow(dist, power)
		
			var dels_weights = dels*weights
        		var deln_weights = deln*weights

			sum_delx_sqr = sum_delx_sqr + dels*dels_weights
        		sum_dely_sqr = sum_dely_sqr + deln*deln_weights

			sum_delx_dely = sum_delx_dely + dels*deln_weights
			
			var qtilde_i : double[4]
			var qtilde_k : double[4]
			for i = 0, 4 do
				qtilde_i[i] = globaldata[idx].q[i] - 0.5 * delx * globaldata[idx].dq[0][i] + dely * globaldata[idx].dq[1][i]
				qtilde_k[i] = globaldata[itm].q[i] - 0.5 * delx * globaldata[itm].dq[0][i] + dely * globaldata[itm].dq[1][i]
			end
						
			var phi_i = venkat_limiter(qtilde_i, globaldata, idx)
			var phi_k = venkat_limiter(qtilde_k, globaldata, idx)
			
			for i = 0, 4 do
				qtilde_i[i] = globaldata[idx].q[i] - 0.5 * phi_i[i] * delx * globaldata[idx].dq[0][i] + dely * globaldata[idx].dq[1][i]
				qtilde_k[i] = globaldata[itm].q[i] - 0.5 * phi_k[i] * delx * globaldata[itm].dq[0][i] + dely * globaldata[itm].dq[1][i]
			end
			
			var result : double[4] = qtilde_to_primitive(qtilde_i)
			var G_i : double[4] = flux_quad_GxIII(nx, ny, result[0], result[1], result[2], result[3])
			result = qtilde_to_primitive(qtilde_k)
			var G_k : double[4] = flux_quad_GxIII(nx, ny, result[0], result[1], result[2], result[3])
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

task outer_dGx_neg(globaldata : region(ispace(int1d), Point), idx : int)
where 
	reads(globaldata.{x, y, nx, ny, xneg_conn, q, dq, minq, maxq, min_dist})
do
	var power : int = 0
	var limiter_flag : int = 1

	var sum_delx_sqr : double = 0
    	var sum_dely_sqr : double = 0
    	var sum_delx_dely : double = 0

	var sum_delx_delf : double[4]
	var sum_dely_delf : double[4]

	for i = 0, 4 do
		sum_delx_delf[i] = 0
		sum_dely_delf[i] = 0
	end

	var x_i = globaldata[idx].x
	var y_i = globaldata[idx].y

	var nx = globaldata[idx].nx
	var ny = globaldata[idx].ny

	var tx = ny
	var ty = -nx

	var itm : int
	for i = 0, 20 do
		itm = globaldata[idx].xneg_conn[i]
		if itm == 0 then
			break
		else
			var x_k = globaldata[itm].x
        		var y_k = globaldata[itm].y

        		var delx = x_k - x_i
        		var dely = y_k - y_i
        		var dels = delx*tx + dely*ty
        		var deln = delx*nx + dely*ny

			var dist = Cmath.sqrt(dels*dels + deln*deln)
        		var weights = Cmath.pow(dist, power)
		
			var dels_weights = dels * weights
        		var deln_weights = deln * weights

			sum_delx_sqr = sum_delx_sqr + dels * dels_weights
        		sum_dely_sqr = sum_dely_sqr + deln * deln_weights

			sum_delx_dely = sum_delx_dely + dels * deln_weights
			
			var qtilde_i : double[4]
			var qtilde_k : double[4]
			for i = 0, 4 do
				qtilde_i[i] = globaldata[idx].q[i] - 0.5 * delx * globaldata[idx].dq[0][i] + dely * globaldata[idx].dq[1][i]
				qtilde_k[i] = globaldata[itm].q[i] - 0.5 * delx * globaldata[itm].dq[0][i] + dely * globaldata[itm].dq[1][i]
			end
						
			var phi_i = venkat_limiter(qtilde_i, globaldata, idx)
			var phi_k = venkat_limiter(qtilde_k, globaldata, idx)
			
			for i = 0, 4 do
				qtilde_i[i] = globaldata[idx].q[i] - 0.5 * phi_i[i] * delx * globaldata[idx].dq[0][i] + dely * globaldata[idx].dq[1][i]
				qtilde_k[i] = globaldata[itm].q[i] - 0.5 * phi_k[i] * delx * globaldata[itm].dq[0][i] + dely * globaldata[itm].dq[1][i]
			end
			
			var result : double[4] = qtilde_to_primitive(qtilde_i)
			var G_i : double[4] = flux_quad_GxIV(nx, ny, result[0], result[1], result[2], result[3])
			result = qtilde_to_primitive(qtilde_k)
			var G_k : double[4] = flux_quad_GxIV(nx, ny, result[0], result[1], result[2], result[3])
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

task outer_dGy_pos(globaldata : region(ispace(int1d), Point), idx : int)
where 
	reads(globaldata.{x, y, nx, ny, ypos_conn, q, dq, minq, maxq, min_dist})
do
	var power : int = 0
	var limiter_flag : int = 1

	var sum_delx_sqr : double = 0
    	var sum_dely_sqr : double = 0
    	var sum_delx_dely : double = 0

	var sum_delx_delf : double[4]
	var sum_dely_delf : double[4]

	for i = 0, 4 do
		sum_delx_delf[i] = 0
		sum_dely_delf[i] = 0
	end

	var x_i = globaldata[idx].x
	var y_i = globaldata[idx].y

	var nx = globaldata[idx].nx
	var ny = globaldata[idx].ny

	var tx = ny
	var ty = -nx

	var itm : int
	for i = 0, 20 do
		itm = globaldata[idx].ypos_conn[i]
		if itm == 0 then
			break
		else
			var x_k = globaldata[itm].x
        		var y_k = globaldata[itm].y

        		var delx = x_k - x_i
        		var dely = y_k - y_i
        		var dels = delx*tx + dely*ty
        		var deln = delx*nx + dely*ny

			var dist = Cmath.sqrt(dels*dels + deln*deln)
        		var weights = Cmath.pow(dist, power)
		
			var dels_weights = dels*weights
        		var deln_weights = deln*weights

			sum_delx_sqr = sum_delx_sqr + dels*dels_weights
        		sum_dely_sqr = sum_dely_sqr + deln*deln_weights

			sum_delx_dely = sum_delx_dely + dels*deln_weights
			
			var qtilde_i : double[4]
			var qtilde_k : double[4]
			for i = 0, 4 do
				qtilde_i[i] = globaldata[idx].q[i] - 0.5 * delx * globaldata[idx].dq[0][i] + dely * globaldata[idx].dq[1][i]
				qtilde_k[i] = globaldata[itm].q[i] - 0.5 * delx * globaldata[itm].dq[0][i] + dely * globaldata[itm].dq[1][i]
			end
						
			var phi_i = venkat_limiter(qtilde_i, globaldata, idx)
			var phi_k = venkat_limiter(qtilde_k, globaldata, idx)
			
			for i = 0, 4 do
				qtilde_i[i] = globaldata[idx].q[i] - 0.5 * phi_i[i] * delx * globaldata[idx].dq[0][i] + dely * globaldata[idx].dq[1][i]
				qtilde_k[i] = globaldata[itm].q[i] - 0.5 * phi_k[i] * delx * globaldata[itm].dq[0][i] + dely * globaldata[itm].dq[1][i]
			end
			
			var result : double[4] = qtilde_to_primitive(qtilde_i)
			var G_i : double[4] = flux_quad_GxIII(nx, ny, result[0], result[1], result[2], result[3])
			result = qtilde_to_primitive(qtilde_k)
			var G_k : double[4] = flux_quad_GxIII(nx, ny, result[0], result[1], result[2], result[3])
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

task main()
	var a : double[4]
	a[0] = 0.1
	a[1] = 0.2
	a[2] = 0.3
	a[3] = -0.4
	var b = qtilde_to_primitive(a)
	for i = 0, 4 do
		C.printf("%lf, ", b[i])
	end
end
regentlib.start(main)
