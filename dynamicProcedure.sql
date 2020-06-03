--exec [proc_StockLedger] @dtFrom = '2019-12-09',@dtTo='2020-12-09',@compID=96,@catId=0,@parent=0,@bid=1,@sid=0,@query=''

alter procedure [dbo].[proc_StockLedger](@dtFrom date,@dtTo date,@compID int,@catId int,@parent int,@bid int,@sid int,@query varchar(50))

as 
begin 


--declare @dtFrom date
--declare @dtTo date
--declare @compID int 
--declare @catId int
--declare @parent int 
--declare @bid int 
--declare @sid int 
--declare @query varchar(50)
----print @str
--select @dtFrom = '2019-12-09'
--select @dtTo = '2020-12-09'
--select @compID = 96
--select @catId = 89
--select @parent = 0
--select @bid = 1
--select @sid = 0
--select @query = ''

declare @con varchar(500) set @con = ''
if @sid <> 0
select @con += ' and SLocationID=@sid'

declare @search varchar(500) set @search = ' where isnull(Opening,0)<>0 or isnull(InQty,0) <> 0 or isnull(OutQty,0)<>0 '
if @query <> ''
select @search += '  and (ProductName like ''%'' + @query + ''%'' or ProductCode like ''%'' + @query + ''%'')'

if @catId <> 0
select @search += ' and CatID=@catId'

if @parent <> 0
select @search += ' and Parent=@parent'

declare @yearcode int, @YearStartDate datetime, @EndDate datetime
select @yearcode=Yearcode,@YearStartDate=StartDate,@EndDate=EndDate from FiscalYear where @dtFrom between StartDate and EndDate


declare @str nvarchar(max)
set @str = 
'select ProductName,ProductCode,Category,isnull(SectionName,'')SectionName,UnitShortForm,isnull(Opening,0)Opening,isnull(InQty,0) InQty,isnull(OutQty,0)OutQty,isnull(Opening,0) + isnull(InQty,0) - isnull(OutQty,0) Closing,isnull(price,0) Price from vw_product p left join(
select ProductID,sum(Qty) Opening from(
	select ProductID,Qty from ProductOpening where  BranchID=@bid '+ @con +' and YearCode = @yearcode
	union all
	select ProductID,sum([In]-[Out])Qty from Stock where   BranchID=@bid '+ @con +' and TransType<>''O'' and transdate >=@YearStartDate and  transdate < @dtFrom group by ProductID)op group by ProductID
) op on p.ProductID = op.ProductID
left outer join 
(
select ProductID,sum([In])InQty,sum([Out])OutQty from Stock where   BranchID=@bid  '+ @con +' and TransType<>''O'' and transdate between @dtFrom and @dtTo group by ProductID
) c on p.ProductID = c.ProductID
left join
(
select ProductID,sum(Amt)/ sum(Qty) Price from(
select ProductID,Qty,Qty*Price Amt from ProductOpening where qty >0 and Price > 0  and YearCode = @yearcode
union all
select ProductID,[In] Qty,[In]*LedingCost Amt from stock where transtype = ''P'' and [In] > 0 and LedingCost > 0  and transdate >=@YearStartDate and  transdate <= @EndDate
) a group by ProductID
)price on p.ProductID = price.ProductID   '+ @search +''


Declare @ParamDefinition AS NVarchar(2000) 
Set @ParamDefinition = '@bid int,@yearcode int, @YearStartDate datetime,@dtFrom datetime,@dtTo datetime,@EndDate datetime,@sid int,@query varchar(50),@catId int,@parent int'
Execute sp_Executesql     @str,@ParamDefinition,@bid,@yearcode,@YearStartDate,@dtFrom,@dtTo,@EndDate,@sid,@query,@catId,@parent

end