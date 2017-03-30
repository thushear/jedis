package com.github.thushear.jedis;


import org.apache.commons.io.FileUtils;
import org.apache.poi.hssf.usermodel.HSSFWorkbook;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;

/**
 * Created by kongming on 2017/3/30.
 */
public class DataHanler {

    static File file = new File(DataHanler.class.getResource("/data.txt").getPath());


    public static void main(String[] args) throws IOException {




        StringBuilder stringBuilder = new StringBuilder();
        String data = FileUtils.readFileToString(file);
        data = data.replaceAll("\"", "");
        String[] dataArray = data.split(",");
        String commentId = "";
        for (int i = 0; i < dataArray.length; i++) {
            String splitStr = dataArray[i];
            if (splitStr.startsWith("commentId")) {
                String[] commentArray = splitStr.split(":");
                commentId = commentArray[1];
                stringBuilder.append(commentId).append(",");
            }
            if (splitStr.startsWith("old")) {
                String[] scores = splitStr.split(":")[1].split("\\|");
                for (String score : scores) {
                    stringBuilder.append(score).append(",");
                }
                stringBuilder.append("\n");
            }

            if (splitStr.startsWith("new")) {
                stringBuilder.append(commentId).append(",");
                String[] scores = splitStr.split(":")[1].split("\\|");
                for (String score : scores) {
                    stringBuilder.append(score).append(",");
                }
                stringBuilder.append("\n");
            }
        }

        System.out.println(stringBuilder.toString());
        FileUtils.writeStringToFile(new File("D:\\output2.csv"), stringBuilder.toString(), "UTF-8");

//        excelExp("D:\\test.xls");

    }


    /**
     * 传入文件的绝对路径 * * @param filePath
     */
    public static void excelExp(String filePath) {
        Workbook wb = null;
        OutputStream out = null;
        try {
            wb = new HSSFWorkbook();
            Sheet sheet = wb.createSheet("test");
            sheet.setColumnWidth(0, 18 * 256);
            sheet.setColumnWidth(1, 18 * 256);
            Row r = sheet.createRow(0);
            r.createCell(0).setCellValue("ip");
            r.createCell(1).setCellValue("community");
            r.createCell(2).setCellValue("result");
            out = new FileOutputStream(filePath);
            wb.write(out);
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            try {
                out.close();
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }

}
